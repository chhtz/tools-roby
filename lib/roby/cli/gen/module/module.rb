<% indent, open_code, close_code = ::Roby::CLI::Gen.in_module(*module_name[0..-2]) %>
<%= open_code %>
<%= indent %>module <%= module_name.last %>
<%= indent %>end
<%= close_code %>
