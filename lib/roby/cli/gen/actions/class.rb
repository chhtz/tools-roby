<% indent, open_code, close_code = ::Roby::CLI::Gen.in_module(*class_name[0..-2]) %>
<%= open_code %>
<%= indent %>class <%= class_name.last %> < Roby::Actions::Interface
<%= indent %>end
<%= close_code %>