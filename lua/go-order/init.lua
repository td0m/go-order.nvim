local ts_utils = require("nvim-treesitter.ts_utils")

local M = {}

local function get_root(node)
	if node == nil then
		return nil
	end
	if node:type() == "source_file" then
		return node
	end
	return get_root(node:parent())
end

local function get_node_text(bufnr, node)
	local start_row, start_col, end_row, end_col = node:range()
	return vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
end

local function query_first(bufnr, node, query_str)
	local query = vim.treesitter.query.parse_query("go", query_str)
	for _, match in query:iter_captures(node, bufnr, 0, -1) do
		return get_node_text(bufnr, match)
	end
	return nil
end

local function parse_root_nodes()
	local nodes = {}
	local comments = {}

	local at_cursor = ts_utils.get_node_at_cursor()
	local root = get_root(at_cursor)
	if root == nil then
		-- FIXME: handle error
		return
	end

	for node in root:iter_children() do
		local typ = node:type()
		if typ == "\n" or typ == "comment" then
			table.insert(comments, node)
		else
			table.insert(nodes, { comments = comments, node = node })
			comments = {}
		end
	end

	if #comments > 0 then
		table.insert(nodes, { comments = comments, node = nil })
	end

	return nodes
end

local declaration_order = {
	"package_declaration",
	"import_declaration",
	"const_declaration",
	"var_declaration",
	"type_or_method_declaration",
	"function_declaration",
}

local function geti(node)
	local typ = node:type()
	if typ == "type_declaration" or typ == "method_declaration" then
		typ = "type_or_method_declaration"
	end
	for index, value in ipairs(declaration_order) do
		if value == typ then
			return index
		end
	end
	return 0
end

local function is_method_or_type(node)
	return node:type() == "method_declaration" or node:type() == "type_declaration"
end

local function join(a, b)
	local ab = {}
	for _, v in ipairs(a) do
		table.insert(ab, v)
	end
	for _, v in ipairs(b) do
		table.insert(ab, v)
	end
	return ab
end

local function get_type_or_receiver(bufnr, node)
	if node:type() == "method_declaration" then
		return query_first(bufnr, node, "(type_identifier) @id")[1]
	elseif node:type() == "type_declaration" then
		return query_first(bufnr, node, "(type_spec name: (type_identifier) @name)")[1]
	end
end

local function get_method_name(bufnr, node)
	return query_first(bufnr, node, "(field_identifier) @id")[1]
end

local function get_function_name(bufnr, node)
	return query_first(bufnr, node, "(identifier) @id")[1]
end

local function sorter(a, b)
	if a.node == nil or b.node == nil then
		return false
	end
	local ai, bi = geti(a.node), geti(b.node)
	if ai ~= bi then
		return bi > ai
	end

	local bufnr = 0
	if is_method_or_type(a.node) and is_method_or_type(b.node) then
		local aname, bname = get_type_or_receiver(bufnr, a.node), get_type_or_receiver(bufnr, b.node)
		if aname ~= bname then
			return bname > aname
		end
		if b.node:type() == "method_declaration" and a.node:type() == "type_declaration" then
			return true
		end
		if b.node:type() == "method_declaration" and a.node:type() == "method_declaration" then
			return get_method_name(bufnr, b.node) > get_method_name(bufnr, a.node)
		end
	end
	if b.node:type() == "function_declaration" and a.node:type() == "function_declaration" then
		return get_function_name(bufnr, b.node) > get_function_name(bufnr, a.node)
	end
	return false
end

local function print_node(bufnr, node)
	-- THE sort of these is low priority, since :sort works on them
	-- plus, we need to consider how "blocks" and "enums" are handled
	if node:type() == "type_declaration" then
		-- TODO: sort fields
	end
	if node:type() == "const_declaration" then
		-- TODO: sort fields
	end
	if node:type() == "var_declaration" then
		-- TODO: sort fields
	end
	return get_node_text(0, node)
end

function M.order()
	local root_nodes = parse_root_nodes()
	if root_nodes == nil then
		return nil
	end
	table.sort(root_nodes, sorter)

	local lines = {}
	for _, it in ipairs(root_nodes) do
		for _, c in ipairs(it.comments) do
			if c:type() == "\n" then
				table.insert(lines, "")
			else
				lines = join(lines, get_node_text(0, c))
			end
		end
		if it.node ~= nil then
			lines = join(lines, print_node(0, it.node))
		end
	end
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

function M.setup(options)
	require("go-order.config").setup(options)
	vim.api.nvim_create_user_command("GoOrder", M.order, {})
end

-- TODO: GoOrderProject to run GoOrder on all go files in current project
-- TODO: build into an external plugin
-- TODO: add null-ls handler
-- TODO: remove dependency on nvim-treesitter
return M
