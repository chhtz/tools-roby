$LOAD_PATH.unshift File.expand_path('..', File.dirname(__FILE__))
require 'roby/test/common'
require 'roby/test/distributed'
require 'roby/test/tasks/simple_task'

require 'roby'
require 'roby/log'
require 'flexmock'

class TC_Log < Test::Unit::TestCase
    include Roby::Test

    def teardown
	super
	Log.clear_loggers
    end

    def test_start_stop_logger
	FlexMock.use do |mock|
	    Log.add_logger mock
	    assert(Log.logging?)
	    assert_nothing_raised { Log.start_logging }

	    Log.remove_logger mock
	    assert(!Log.logging?)
	    assert_nothing_raised { Log.stop_logging }
	end
    end

    def test_misc
	FlexMock.use do |mock|
	    mock.should_receive(:splat?).and_return(true)
	    mock.should_receive(:event).with(1, 2)
	    mock.should_receive(:flush)
	    Log.add_logger mock

	    assert(Log.has_logger?(:flush))
	    assert(Log.has_logger?(:event))

	    assert_equal([mock], Log.enum_for(:each_logger, :event).to_a)
	    assert_equal([], Log.enum_for(:each_logger, :bla).to_a)
	end
    end

    def test_message_splat
	FlexMock.use do |mock|
	    mock.should_receive(:splat?).and_return(true).twice
	    mock.should_receive(:splat_event).with(FlexMock.any, 1, 2).once
	    mock.should_receive(:flush).once
	    Log.add_logger mock

	    Log.log(:splat_event) { [1, 2] }
	    Log.flush
	end
    end

    def test_message_nonsplat
	FlexMock.use do |mock|
	    mock.should_receive(:splat?).and_return(false).twice
	    mock.should_receive(:nonsplat_event).with(FlexMock.any, [1, 2]).once
	    mock.should_receive(:flush).once
	    Log.add_logger mock

	    Log.log(:nonsplat_event) { [1, 2] }
	    Log.flush
	end
    end

    def on_marshalled_task(task)
	FlexMock.on do |obj| 
	    obj.remote_siblings[Roby::Distributed.droby_dump(nil)] == task.remote_id
	end
    end
    def test_known_objects_management
	t1, t2 = SimpleTask.new, SimpleTask.new
	FlexMock.use do |mock|
	    mock.should_receive(:splat?).and_return(true)
	    mock.should_receive(:added_task_child).
		with(FlexMock.any, on_marshalled_task(t1), [TaskStructure::Hierarchy].droby_dump(nil), 
		     on_marshalled_task(t2), FlexMock.any).once

	    match_discovered_set = FlexMock.on do |task_set| 
		task_set.map { |obj| obj.remote_siblings[Roby::Distributed.droby_dump(nil)] }.to_set == [t1.remote_id, t2.remote_id].to_set
	    end

	    mock.should_receive(:discovered_tasks).
		with(FlexMock.any, FlexMock.any, match_discovered_set).
		once
	    mock.should_receive(:removed_task_child).
		with(FlexMock.any, t1.remote_id, [TaskStructure::Hierarchy].droby_dump(nil), t2.remote_id).
		once
	    mock.should_receive(:finalized_task).
		with(FlexMock.any, FlexMock.any, t1.remote_id).
		once

	    Log.add_logger mock
	    begin
		t1.realized_by t2
		assert(Log.known_objects.empty?)
		plan.discover(t1)
		assert_equal([t1, t2].to_value_set, Log.known_objects)
		t1.remove_child t2
		assert_equal([t1, t2].to_value_set, Log.known_objects)
		plan.remove_object(t1)
		assert_equal([t2].to_value_set, Log.known_objects)

		Log.flush
	    ensure
		Log.remove_logger mock
	    end
	end
    end
end
