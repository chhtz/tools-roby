$LOAD_PATH.unshift File.expand_path(File.join('..', 'lib'), File.dirname(__FILE__))
require 'flexmock'
require 'roby/test/common'
require 'roby/tasks/simple'
require 'flexmock'
require 'roby/log'

class TC_TaskScripting < Test::Unit::TestCase
    include Roby::Test
    include Roby::Test::Assertions

    def test_execute
        task = prepare_plan :missions => 1, :model => Roby::Tasks::Simple
        counter = 0
        task.script do
            execute do
                counter += 1
            end
        end
        task.start!

        process_events
        process_events
        process_events
        assert_equal 1, counter
    end

    def test_execute_and_emit
        task = prepare_plan :missions => 1, :model => Roby::Tasks::Simple
        counter = 0
        task.script do
            execute do
                counter += 1
            end
            emit :success
        end
        task.start!

        process_events
        process_events
        process_events
        process_events
        assert_equal 1, counter
        assert task.success?
    end

    def test_poll
        task = prepare_plan :missions => 1, :model => Roby::Tasks::Simple
        counter = 0
        task.script do
            poll do
                counter += 1
            end
            emit :success
        end
        task.start!

        process_events
        process_events
        process_events
        assert_equal 4, counter
    end

    def test_poll_end_if
        task = prepare_plan :missions => 1, :model => Roby::Tasks::Simple
        counter = 0
        FlexMock.use do |mock|
            task.script do
                poll do
                    counter += 1

                    end_if do
                        mock.test_called
                        counter > 2
                    end
                end
                emit :success
            end
            mock.should_receive(:test_called).times(3)
            task.start!

            6.times { process_events }
            assert_equal 3, counter
        end
    end

    def test_poll_delayed_end_condition
        task = prepare_plan :missions => 1, :model => Roby::Tasks::Simple
        counter = 0
        task.script do
            poll do
                counter += 1
                end_if do
                    if counter > 2
                        wait(2)
                    end
                end
            end
            emit :success
        end

        FlexMock.use(Time) do |mock|
            time = Time.now
            mock.should_receive(:now).and_return { time }
            
            task.start!
            6.times { process_events }
            assert_equal 7, counter

            time += 3
            6.times { process_events }
            assert_equal 8, counter
        end
    end

    def test_wait
        model = Class.new(Roby::Tasks::Simple) do
            event :intermediate
        end
        task = prepare_plan :missions => 1, :model => model
        counter = 0
        task.script do
            wait :intermediate
            execute { counter += 1 }
        end
        task.start!

        3.times { process_events }
        assert_equal 0, counter
        task.emit :intermediate
        3.times { process_events }
        assert_equal 1, counter
    end

    def test_wait_for_child_event
        model = Class.new(Roby::Tasks::Simple) do
            event :intermediate
        end
        parent, child = prepare_plan :missions => 1, :add => 1, :model => model
        parent.depends_on(child, :role => 'subtask')

        counter = 0
        parent.script do
            wait intermediate_event
            execute { counter += 1 }
            wait subtask_child.intermediate_event
            execute { counter += 1 }
        end
        parent.start!
        child.start!

        3.times { process_events }
        assert_equal 0, counter
        parent.emit :intermediate
        3.times { process_events }
        assert_equal 1, counter
        child.emit :intermediate
        3.times { process_events }
        assert_equal 2, counter
    end

    def test_wait_for_child_of_child_event_with_child_being_deployed_later
        model = Class.new(Roby::Tasks::Simple) do
            event :intermediate
        end
        parent, (child, planning_task) = prepare_plan :missions => 1, :add => 2, :model => model
        parent.depends_on(child, :role => 'subtask')
        child.abstract = true
        child.planned_by(planning_task)
        planning_task.on :start do
            child.depends_on(model.new, :role => 'subsubtask')
            child.abstract = false
            planning_task.emit :success
        end

        planning_task.executable = false

        counter = 0
        parent.script do
            wait intermediate_event
            execute { counter += 1 }
            wait subtask_child.subsubtask_child.intermediate_event
            execute { counter += 1 }
        end
        parent.start!

        3.times { process_events }
        assert_equal 0, counter
        parent.emit :intermediate
        3.times { process_events }

        assert(planning_task.pending?)
        assert(child.pending?)
        assert_equal 1, counter

        planning_task.executable = true
        planning_task.start!
        3.times { process_events }
        assert_equal 1, counter

        child.subsubtask_child.start!
        child.subsubtask_child.emit :intermediate
        3.times { process_events }
        assert_equal 2, counter
    end

    def test_wait_for_duration
        task = prepare_plan :missions => 1, :model => Roby::Tasks::Simple

        FlexMock.use(Time) do |mock|
            time = Time.now
            mock.should_receive(:now).and_return { time }
            task.script do
                wait 5
                emit :success
            end

            task.start!
            process_events
            assert !task.finished?
            time = time + 3
            process_events
            assert !task.finished?
            time = time + 3
            process_events
            assert task.finished?
        end
    end

    def test_wait_after
        task = prepare_plan :missions => 1, :model => Roby::Tasks::Simple

        task.start!
        assert task.running?
        task.script do
            wait start_event
            emit :success
        end
        process_events
        assert task.running?

        task = prepare_plan :missions => 1, :model => Roby::Tasks::Simple
        time = Time.now
        task.start!
        task.script do
            wait start_event, :after => time
            emit :success
        end
        process_events
        assert !task.running?
    end

    def test_wait_barrier
        model = Class.new(Roby::Tasks::Simple) do
            3.times do |i|
                event "event#{i + 1}"
                event "found_event#{i + 1}"
            end
        end
        task = prepare_plan :missions => 1, :model => model

        task.script do
            wait_any event1_event
            emit :found_event1
            wait event2_event
            emit :found_event2
            wait event3_event
            emit :found_event3
        end

        task.start!
        task.emit :event1
        task.emit :event2
        task.emit :event3
        process_events
        assert task.found_event1?
        assert task.found_event2?
        assert task.found_event3?
    end

    def test_timeout_pass
        model = Class.new(Roby::Tasks::Simple) do
            event :intermediate
            event :timeout
        end
        task = prepare_plan :missions => 1, :model => model

        FlexMock.use(Time) do |mock|
            time = Time.now
            mock.should_receive(:now).and_return { time }

            plan.add(task)
            task.script do
                timeout 5, :emit => :timeout do
                    wait intermediate_event
                end
                emit :success
            end
            task.start!

            process_events
            assert task.running?
            task.emit :intermediate
            process_events
            assert task.success?
        end
    end

    def test_timeout_fail
        model = Class.new(Roby::Tasks::Simple) do
            event :intermediate
            event :timeout
        end
        task = prepare_plan :missions => 1, :model => model

        FlexMock.use(Time) do |mock|
            time = Time.now
            mock.should_receive(:now).and_return { time }

            plan.add(task)
            task.script do
                timeout 5, :emit => :timeout do
                    wait intermediate_event
                end
                emit :success
            end
            task.start!

            process_events
            assert task.running?
            time += 6
            process_events
            assert task.timeout?
        end
    end

    def test_parallel_scripts
        model = Class.new(Roby::Tasks::Simple) do
            event :start_script1
            event :done_script1
            event :start_script2
            event :done_script2
        end
        task = prepare_plan :permanent => 1, :model => model

        task.script do
            wait start_script1_event
            emit :done_script1
        end
        task.script do
            wait done_script2_event
            emit :done_script2
        end

        process_events
        task.start!
        process_events
        task.emit :start_script1
        process_events
        assert task.done_script1?
        assert !task.done_script2?
        task.stop!
        assert task.done_script1?
        assert !task.done_script2?
    end
end
