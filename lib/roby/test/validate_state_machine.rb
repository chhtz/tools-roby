module Roby
    module Test
        # Implementation of the #validate_state_machine context
        class ValidateStateMachine
            def initialize(test, task_or_action)
                @test = test
                @toplevel_task = @test.roby_run_planner(task_or_action)

                @state_machines = @toplevel_task.coordination_objects.
                    find_all { |obj| obj.kind_of?(Coordination::ActionStateMachine) }
                if @state_machines.empty?
                    raise ArgumentError, "#{task_or_action} has no state machines"
                end
            end

            def assert_transitions_to_state(state_name, timeout: 5, start: true)
                if state_name.respond_to?(:to_str) && !state_name.end_with?('_state')
                    state_name = "#{state_name}_state"
                end

                done = false
                @state_machines.each do |m|
                    m.on_transition do |_, new_state|
                        if state_name === new_state.name
                            done = true
                        end
                    end
                end
                yield if block_given?
                @test.process_events_until(timeout: timeout, garbage_collect_pass: false) do
                    done
                end
                @test.roby_run_planner(@toplevel_task)
                state_task = @toplevel_task.current_task_child
                if start
                    @test.assert_event_emission state_task.start_event
                end
                state_task
            end

            def evaluate(&block)
                instance_eval(&block)
            end

            def find_event(name)
                @toplevel_task.find_event(name)
            end

            def find_child_from_role(name)
                @toplevel_task.find_child(name)
            end

            MetaRuby::DSLs.setup_find_through_method_missing self,
                event: 'find_event',
                child: 'find_child_from_role'

            def method_missing(m, *args, &block)
                if @test.respond_to?(m)
                    @test.public_send(m, *args, &block)
                else
                    super
                end
            end
        end
    end
end

