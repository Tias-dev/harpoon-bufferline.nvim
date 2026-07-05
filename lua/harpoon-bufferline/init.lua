local function GetAbsPath(path)
    if string.sub(path, 1, 1) == "/" then
        return path
    end
    return vim.fn.getcwd() .. "/" .. path
end

---@param item HarpoonListItem
local function GetBufferLineBufferFromHarpoonItem(bufferline, item, bufnr)
    local absPath = GetAbsPath(item.value)
    if bufnr then
        local basename = vim.fs.basename(absPath)
        return {
            id = bufnr,
            name = basename,
            path = absPath,
        }
    end
    for _, bufferElement in ipairs(bufferline.get_elements().elements) do
        if bufferElement.path == absPath then
            return bufferElement
        end
    end
    return nil
end
local log = require("harpoon-bufferline.util.log")
local config = require("harpoon-bufferline.config")

local HarpoonBufferline = {}

-- proper way to clear harpoon list with bufferline sync
function HarpoonBufferline.clearList()
    require("harpoon"):list():clear()
    local bufferline = require("bufferline")
    local harpoonedBuffers = {}
    bufferline.groups.action(HarpoonBufferline.group, function(b)
        table.insert(harpoonedBuffers, b)
    end)
    for _, b in ipairs(harpoonedBuffers) do
        bufferline.groups.remove_element(HarpoonBufferline.group, b)
    end
end

local FitListImpl = function(list)
    local len = list:length()
    local isSquashNeed = false
    for i = 1, len do
        if not list:get(i) then
            isSquashNeed = true
            break
        end
    end
    if not isSquashNeed then
        return
    end

    local items = {}
    for i = 1, len do
        local item = list:get(i)
        if item then
            table.insert(items, item)
        end
    end
    list:clear()
    for _, item in ipairs(items) do
        list:add(item)
    end
end

local FitList = function(list)
    HarpoonBufferline.isFittingNow = true
    FitListImpl(list)
    HarpoonBufferline.isFittingNow = false
end

local function normalize_path(buf_name, root)
    return require("plenary.path"):new(buf_name):make_relative(root)
end

local SortFunction = function(buffer_a, buffer_b)
    local list = require("harpoon"):list()
    local item_a, idx_a = list:get_by_value(normalize_path(buffer_a.path, vim.fn.getcwd()))
    local item_b, idx_b = list:get_by_value(normalize_path(buffer_b.path, vim.fn.getcwd()))
    if item_a and item_b then
        return idx_a > idx_b
    elseif item_a then
        return true
    elseif item_b then
        return false
    end
    return buffer_a.path > buffer_b.path
end
local SortFunctionById = function(buffer_a, buffer_b)
    return buffer_a.id > buffer_b.id
end

-- setup HarpoonBufferline, assume that harpoon2 and bufferline already setuped
function HarpoonBufferline.setup(opts)
    opts = opts or {}
    local group = opts.group or config.DEFAULT_GROUP
    HarpoonBufferline.group = group
    HarpoonBufferline.isFittingNow = false
    local harpoon = require("harpoon")
    local bufferline = require("bufferline")
    local fit_harpoon = opts.fit_harpoon_storage_on_remove or config.fit_harpoon_storage_on_remove
    local sort_buffers = opts.order_bufferline_as_harpoon or config.order_bufferline_as_harpoon
    local harpoon_list = harpoon:list()

    -- initial buffers setup
    vim.schedule(function()
        for i = 1, harpoon_list:length() do
            local item = harpoon_list:get(i)

            local bufnr = vim.fn.bufadd(item.value)
            vim.fn.bufload(bufnr)
            vim.api.nvim_buf_set_option(bufnr, "buflisted", true)

            local buffer = GetBufferLineBufferFromHarpoonItem(bufferline, item, bufnr)
            if not buffer then
                log.notify(
                    "harpoon Initial",
                    vim.log.levels.WARN,
                    "Can't find bufferline buffer for item: %s",
                    item.value
                )
                goto continue
            end
            bufferline.groups.add_element(group, buffer)
            ::continue::
        end
    end)
    vim.defer_fn(function()
        if fit_harpoon then
            FitList(harpoon_list)
        end
        if sort_buffers then
            bufferline.sort_by(SortFunction)
        end
    end, 1000)
    -- extend harpoon by callbacks on add and remove buffers
    harpoon:extend({
        ADD = function(ctx)
            if HarpoonBufferline.isFittingNow then
                return
            end
            local item = ctx.item
            local buffer = GetBufferLineBufferFromHarpoonItem(bufferline, item)
            if not buffer then
                log.notify(
                    "harpoon ADD extend",
                    vim.log.levels.WARN,
                    "Can't find bufferline buffer for item: %s",
                    item.value
                )
                return
            end
            bufferline.groups.add_element(group, buffer)
            if fit_harpoon then
                FitList(ctx.list)
            end
            if sort_buffers then
                bufferline.sort_by(SortFunction)
            end
        end,
        REMOVE = function(ctx)
            if HarpoonBufferline.isFittingNow then
                return
            end
            local item = ctx.item
            local buffer = GetBufferLineBufferFromHarpoonItem(bufferline, item)
            if not buffer then
                log.notify(
                    "harpoon REMOVE extend",
                    vim.log.levels.WARN,
                    "Can't find bufferline buffer for item: %s",
                    item.value
                )
                return
            end
            bufferline.groups.remove_element(group, buffer)
            if fit_harpoon then
                FitList(ctx.list)
            end
            if sort_buffers then
                bufferline.sort_by(SortFunction)
            end
        end,
    })
end

_G.HarpoonBufferline = HarpoonBufferline

return _G.HarpoonBufferline
