local http = require("socket.http")
local json = require("json")
local logger = require("logger")
local ltn12 = require("ltn12")
local socket = require("socket")
local socketutil = require("socketutil")

local XMNoteClient = {
    server_ip = "localhost",
    server_port = 8080
}

function XMNoteClient:new(o)
    o = o or {}
    self.__index = self
    setmetatable(o, self)
    return o
end

function XMNoteClient:_makeRequest(endpoint, method, request_body)
    local sink = {}
    local request_body_json = json.encode(request_body)
    local source = ltn12.source.string(request_body_json)
    socketutil:set_timeout(socketutil.LARGE_BLOCK_TIMEOUT, socketutil.LARGE_TOTAL_TIMEOUT)
    local url = "http://".. self.server_ip .. ":" .. self.server_port .. endpoint
    local request = {
        url     = url,
        method  = method,
        sink    = ltn12.sink.table(sink),
        source  = source,
        headers = {
            ["Content-Length"] = #request_body_json,
            ["Content-Type"] = "application/json"
        },
    }
    local code, _, status = socket.skip(1, http.request(request))
    socketutil:reset_timeout()

    if code ~= 200 then
        logger.warn("XMNoteClient: HTTP response code <> 200. Response status: ", status)
        error("XMNoteClient: HTTP response code <> 200.")
    end

    local response = json.decode(sink[1])
    local code = response["code"]
    if code ~= nil and code ~= 200 then
        logger.warn("XMNoteClient: response code <> 200. message: ", response["message"])
        error("XMNoteClient: response code <> 200.")
    end
    return response
end

function XMNoteClient:_createRequestBody(booknotes)
    local book = {
        title = "",
        type = 1,
        locationUnit = 1,
    }
    local entries = {}
    book.title = booknotes.title or ""
    for _, chapter in ipairs(booknotes) do
        for _, clipping in ipairs(chapter) do
            local entry = {
                page = clipping.page,
                text = clipping.text,
                note = clipping.note or "",
                chapter = clipping.chapter,
                time = clipping.time
            }
            table.insert(entries, entry)
        end
    end
    book.entries = entries
    return book
end


function XMNoteClient:sendBooknotes(bookNotes)
    local body = self:_createRequestBody(bookNotes)
    local result =self:_makeRequest("/send", "POST", body)
    logger.dbg("XMNoteClient sendBooknotes result", result)
end

return XMNoteClient