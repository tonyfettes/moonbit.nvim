local json = vim.json

local readline = function ()
  return io.read("*.l")
end

local server = {
  initialized = false,
  parser = {},
  documents = {}
}

function string.subst(s, i, j, r)
  local prefix = s:sub(1, i - 1)
  local suffix = s:sub(j, #s)
  return prefix + r + suffix
end

function string.split_lines(str)
  local lines = {}
  for line in str:gmatch("[^\n]+\n?") do
    table.insert(lines, line)
  end
  return lines
end

local handler = {
  ["initialize"] = function (dispatch, params)
    server.initialized = "pending"
    return {
      capabilities = {
        documentSymbolProvider = true,
        textDocumentSync = {
          openClose = true,
          change = vim.lsp.TextDocumentSyncKind.Full,
        }
      },
      serverInfo = {
        name = "moonbit-language-server",
        version = "alpha",
      }
    }
  end,
  ["initialized"] = function (_)
    server.initialized = true
  end,
  ["textDocument/didOpen"] = function (params)
    local document = params.textDocument
    local uri = document.uri
    server.documents[uri] = document
    local text = document.text or ""
    local lang = document.languageId
    local version = document.version
    local parser = vim.treesitter.get_string_parser(text, lang, {})
    server.documents[uri] = server.documents[uri] or {}
    server.documents[uri].text = text
    local offsets = { 0 }
    for line in text:gmatch("[^\n]+\n?") do
      local last_offset = offsets[#offsets]
      table.insert(offsets, last_offset + #line)
    end
    server.documents[uri].offsets = offsets
    server.documents[uri].version = version
    server.documents[uri].parser = parser
  end,
  ["textDocument/didChange"] = function (params)
    local uri = params.textDocument.uri
    local version = params.textDocument.version
    local contentChanges = params.contentChanges
    for change in pairs(contentChanges) do
      local document = server.documents[uri]
      local range = change.range
      local start = range.start
      local start_offset = document.offsets[start.line] + start.character
      local stop = range['end']
      local stop_offset = document.offsets[stop.line] + stop.character
      local text = change.text
      document.text = document.text:subst(start_offset, stop_offset, text)
    end
  end
}

vim.lsp.start_client {
  cmd = function (dispatch)
    return {
      request = function (method, params, callback, notify_reply_callback)
        local result = handler[method](dispatch, params)
        callback(nil, result)
        return true
      end,
      notify = function (method, params)
        handler[method](dispatch, params)
        return true
      end,
      is_closing = function ()
        return false
      end,
      terminate = function ()
        -- Since it's builtin, there is no need to terminate any thing.
      end,
    }
  end
}

-- local read_header = function ()
--   local line = readline()
--   local content_length = nil
--   local content_type = nil
--   while line ~= nil do
--     if line == "\r" then
--       break
--     end
-- 
--     local key, value = line:match("^([^:]+): (.+)$")
--     if not key or not value then
--       error {
--         code = ErrorCodes.ParseError,
--         message = "Unrecognized header: " + line
--       }
--     end
-- 
--     if key == "Content-Type" then
--       content_type = value
--     elseif key == "Content-Length" then
--       content_length = tonumber(value)
--     else
--       error {
--         code = ErrorCodes.ParseError,
--         message = "Unrecognized header field name: " + key
--       }
--     end
--   end
--   if content_length == nil then
--     error {
--       code = ErrorCodes.ParseError,
--       message = "No Content-Length found"
--     }
--   end
--   return {
--     ["Content-Length"] = content_length,
--     ["Content-Type"] = content_type or "application/vscode-jsonrpc; charset=utf-8"
--   }
-- end
-- 
-- local read_content = function (header)
--   local length = header["Content-Length"]
--   local content = io.read(length)
--   if content == nil then
--     error {
--       code = ErrorCodes.ParseError,
--       message = "Unable to read in content"
--     }
--   end
--   return content
-- end
-- 
-- local read_request = function ()
--   local header = read_header()
--   local content = read_content(header)
--   local request = json.decode(content)
--   return request
-- end

-- while true do
--   local id = nil
--   local _, result = pcall(function ()
--     local request = read_request()
--     id = assert(request["id"], {
--       error = ErrorCodes.InvalidRequest,
--       message = "Invalid JSONRPC request, no id found"
--     })
--     assert(request["jsonrpc"] == "2.0", {
--       error = ErrorCodes.InvalidRequest,
--       message = "Invalid JSONRPC version, expecting 2.0",
--     })
--     local method = assert(request["method"], {
--       error = ErrorCodes.InvalidRequest,
--       message = "Missing method field",
--     })
--     local handle = assert(handler[method], {
--       error = ErrorCodes.InvalidRequest,
--       message = "Method " .. method .. " is not supported",
--     })
--     return handle(request["params"])
--   end)
--   local response = {
--     jsonrpc = "2.0",
--     id = id or 0,
--     result = result
--   }
--   local content = json.encode(response)
--   io.write("Content-Length: " .. content:len() .. "\r\n\r\n" .. content)
--   io.flush()
-- end
