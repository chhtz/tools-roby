require 'roby/test/self'

module Roby
    module Queries
        describe Index do
            attr_reader :index
            before do
                @index = Index.new
            end

            it "registers in per-model mappings using #each_fullfilled_model" do
                task_m = Task.new_submodel
                task = Roby::Task.new
                flexmock(task.model).should_receive(:each_fullfilled_model).
                    and_return([task_m])

                index.add(task)
                assert_equal Set[task], index.by_model[task_m]
                index.remove(task)
                assert_equal Set[], index.by_model[task_m]
            end
        end
    end
end
