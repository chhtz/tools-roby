require 'roby/test/self'
require 'roby/droby/logfile/index'
require 'roby/droby/logfile/writer'
require 'roby/droby/logfile/reader'

require 'droby/helpers'

module Roby
    module DRoby
        module Logfile
            describe Index do
                include TestHelpers

                describe "prologue" do
                    it "can write and read a prologue" do
                        base_time = Time.now
                        File.open(logfile_path('roby-events.idx'), 'w') do |io|
                            Index.write_prologue(io, 10, base_time)
                        end
                        File.open(logfile_path('roby-events.idx'), 'r') do |io|
                            assert_equal [Index::VERSION, 10, base_time], Index.read_prologue(io)
                        end
                    end

                    def assert_invalid_prologue(exception = InvalidIndex)
                        File.open(logfile_path('roby-events.idx'), 'r') do |io|
                            assert_raises(exception) do
                                Index.read_prologue(io)
                            end
                        end
                    end

                    it "raises if the file does not start with the magic" do
                        File.open(logfile_path('roby-events.idx'), 'w') do |io|
                            Index.write_prologue(io, 10, Time.now, magic: "BADY_MAGIC")
                        end
                        assert_invalid_prologue
                    end
                    it "raises if the format version is wrong" do
                        File.open(logfile_path('roby-events.idx'), 'w') do |io|
                            Index.write_prologue(io, 10, Time.now, version: 0)
                        end
                        assert_invalid_prologue(InvalidIndexFormat)
                    end
                    it "raises if the file is shorter than the magic" do
                        File.open(logfile_path('roby-events.idx'), 'w') do |io|
                            Index.write_prologue(io, 10, Time.now)
                            io.truncate(5)
                        end
                        assert_invalid_prologue(InvalidIndex)
                    end
                    it "raises if the file is shorter than the additional prologue data" do
                        File.open(logfile_path('roby-events.idx'), 'w') do |io|
                            Index.write_prologue(io, 10, Time.now)
                            io.truncate(10)
                        end
                        assert_invalid_prologue(InvalidIndex)
                    end
                end

                describe ".rebuild" do
                    it "indexes the cycle data and associates it with the position in the event log" do
                        create_event_log 'events.log' do
                            write_event :event
                            write_event_cycle_end Hash[test: 10], time: Time.now
                        end
                        File.open(logfile_path('events.log')) do |event_io|
                            File.open(logfile_path('events.idx'), 'w') do |index_io|
                                Index.rebuild(event_io, index_io)
                            end
                        end
                        index = Index.read(logfile_path('events.idx'))

                        assert_equal 1, index.data.size
                        assert_equal 10, index.data[0][:test]
                        pos = index.data[0][:pos]

                        event_io = open_event_log_io('events.log')
                        event_io.seek(pos)
                        cycle = ::Marshal.load(Logfile.read_one_chunk(event_io))
                        assert_equal [Hash[test: 10]], cycle[-1]
                    end
                    it "raises if the source file has a cycle whose last message is not cycle_end" do
                        create_event_log 'events.log' do
                            write_event :event
                            @event_logger.write_current_cycle
                        end
                        File.open(logfile_path('events.log')) do |event_io|
                            File.open(logfile_path('events.idx'), 'w') do |index_io|
                                assert_raises(InvalidFileError) do
                                    Index.rebuild(event_io, index_io)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
