-- -*- mode: lua; tab-width: 2; indent-tabs-mode: 1; st-rulers: [70] -*-
-- vim: ts=4 sw=4 ft=lua noet
----------------------------------------------------------------------
-- @author Daniel Barney <daniel@pagodabox.com>
-- @copyright 2015, Daniel Barney.
-- @doc
--
-- @end
-- Created :   3 Aug 2015 by Daniel Barney <daniel@pagodabox.com>
----------------------------------------------------------------------

-- need custom wrappers to support returning nil.
function exports.reader(decoder,read)
  local buffer = ''
  local decode = decoder()
  return function()
    while true do
      local chunk, rest = decode(buffer)
      if rest then
        buffer = rest
        return chunk
      end
      local next_chunk = read()
      if next_chunk == nil then return nil end
      buffer = buffer .. next_chunk
    end
  end
end

function exports.writer(encoder,write)
  local encode = encoder()
  return function(...)
    local data = encode(...)
    return write(data)
  end
end