module Roby
    module DRoby
        module Logfile
            class InvalidIndex < RuntimeError; end
            class InvalidIndexFormat < InvalidIndex; end

            # A logfile index
            class Index
                MAGIC   = "ROBY_INDEX"
                PROLOGUE_SIZE = MAGIC.size + 20
                VERSION = 1

                # Read the index file prologue and return the format version
                #
                # @raise [InvalidIndex] if the index is not valid
                # @raise [InvalidIndexFormat] if the format does not match
                #   {VERSION}. Note that InvalidIndexFormat subclasses
                #   InvalidIndex
                def self.read_prologue(io, validate_version: true)
                    prologue = io.read(PROLOGUE_SIZE)
                    if !prologue || prologue.size < PROLOGUE_SIZE
                        raise InvalidIndex, "expected a prologue of #{PROLOGUE_SIZE}, but got only #{prologue.size}"
                    end
                    magic = prologue[0, MAGIC.size]
                    if magic != MAGIC
                        raise InvalidIndex, "expected index to start with #{MAGIC} but got #{magic}"
                    end

                    format, size, mtime = prologue[MAGIC.size..-1].unpack("L<Q<Q<")
                    if validate_version && (format != VERSION)
                        raise InvalidIndexFormat, "invalid index format #{format}, expected #{VERSION}"
                    end

                    return format, size, Time.at(Rational(mtime, 1_000_000_000))
                end

                # Write an index file prologue
                def self.write_prologue(io, file_size, file_mtime, magic: MAGIC, version: VERSION)
                    file_mtime = file_mtime.tv_sec * 1_000_000_000 + file_mtime.tv_nsec
                    io.write(magic + [version, file_size, file_mtime].pack("L<Q<Q<"))
                end

                # Creates an index file for +event_log+ in +index_log+
                def self.rebuild(event_io, index_io)
                    stat = event_io.stat
                    event_log = Reader.new(event_io)

                    write_prologue(index_io, stat.size, stat.mtime)
                    while !event_log.eof?
                        current_pos = event_log.tell
                        cycle = event_log.load_one_cycle
                        if cycle[-4] != :cycle_end
                            raise InvalidFileError, "expected cycle data to end with :cycle_end, but got #{cycle[-4]}"
                        end
                        info  = cycle[-1].last
                        event_count = 0
                        cycle.each_slice(4) do |m, *|
                            if m.to_s !~ /^timepoint/
                                event_count += 1
                            end
                        end
                        info[:event_count] = event_count
                        info[:pos] = current_pos

                        info = ::Marshal.dump(info)
                        index_io.write [info.size].pack("L<")
                        index_io.write info
                    end

                rescue EOFError
                ensure index_io.flush if index_io
                end

                # The size in bytes of the file that has been indexed
                attr_reader :file_size
                # The modification time of the file that has been indexed
                attr_reader :file_time
                # The index data
                #
                # @return [Array<Hash>]
                attr_reader :data

                def initialize(file_size, file_time, data)
                    @file_size = file_size
                    @file_time = file_time
                    @data = data
                end

                def size
                    data.size
                end

                def [](*args)
                    data[*args]
                end

                def each(&block)
                    data.each(&block)
                end

                include Enumerable

                # Tests whether this index is valid for a given file
                #
                # @param [String] path the log file path
                # @return [Boolean]
                def valid_for?(path)
                    stat = File.stat(path)
                    stat.size == file_size && stat.mtime == file_time
                end

                # Returns the number of cycles in this index
                def cycle_count
                    data.size
                end

                # Tests whether this index contains cycles
                def empty?
                    data.empty?
                end

                # The time range
                #
                # @return [nil,(Time,Time)]
                def range
                    if !data.empty?
                        [Time.at(*data.first[:start]), 
                         Time.at(*data.last[:start]) + data.last[:end]]
                    end
                end

                # Read an index file
                #
                # @param [String] filename the index file path
                def self.read(filename)
                    io = File.open(filename)
                    _version, size, mtime = read_prologue(io)
                    data = Array.new
                    begin
                        while !io.eof?
                            data << ::Marshal.load(Logfile.read_one_chunk(io))
                        end
                    rescue EOFError
                    end

                    new(size, mtime, data)
                ensure
                    io.close if io
                end
            end
        end
    end
end

