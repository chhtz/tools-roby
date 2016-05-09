module Roby
    module Interface
        # Representation of a subcommand on {Interface} on the client side
        class ClientSubcommand
            # @return [Client,ClientSubcommand] the parent shell /
            #   subcommand
            attr_reader :parent
            # @return [
            # @return [String] the subcommand name
            attr_reader :name
            # @return [String] the subcommand description
            attr_reader :description
            # @return [String] the set of commands on this subcommand
            attr_reader :commands

            def initialize(parent, name, description, commands)
                @parent, @name, @description, @commands =
                    parent, name, description, commands
            end

            # Tests whether self has a given subcommand
            def has_subcommand?(name)
                commands.has_key?(name)
            end

            # Returns an object that gives access to the commands on a
            # subcommand of self
            def subcommand(name)
                if !(sub = find_subcommand_by_name(name))
                    raise ArgumentError, "#{name} is not a known subcommand on #{self}"
                end
                ClientSubcommand.new(self, name, sub.description, sub.commands)
            end

            def call(path, m, *args)
                parent.call([name] + path, m, *args)
            end

            def path
                parent.path + [name]
            end

            def method_missing(m, *args)
                parent.call([name], m, *args)
            rescue NoMethodError => e
                if e.message =~ /undefined method .#{m}./
                    raise NoMethodError, "invalid command name #{m} on #{path.join(".")}", e.backtrace
                else raise
                end
            end
        end
    end
end

