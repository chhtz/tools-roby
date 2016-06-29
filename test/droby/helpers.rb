require 'roby/droby/logfile/writer'
require 'roby/droby/event_logger'

module Roby
    module DRoby
        module TestHelpers
            def setup
                super
                @logdir = Dir.mktmpdir
                io = StringIO.new
            end

            def teardown
                FileUtils.rm_rf @logdir
                if @event_io && !@event_io.closed?
                    @event_io.close
                end
            end

            def logfile_path(*path)
                File.join(@logdir, *path)
            end

            def create_event_log(path)
                if @event_io
                    @event_io.close
                end
                @event_io = File.open(logfile_path(path), 'w+')
                @event_writer = Logfile::Writer.new(@event_io)
                @event_logger = EventLogger.new(@event_writer, queue_size: 0)

                begin
                    yield
                    if @event_logger.has_pending_cycle?
                        write_event_cycle_end
                    end
                ensure
                    @event_writer.flush
                    @event_io.close
                    @event_io = nil
                end
            end

            def write_event(m, *args, time: Time.now)
                @event_logger.dump(m, time, args)
            end

            def write_event_cycle_end(values = Hash.new, time: Time.now)
                write_event(:cycle_end, values, time: time)
            end

            def open_event_log_io(*path)
                @event_io = File.open(logfile_path(*path))
            end
        end
    end
end



