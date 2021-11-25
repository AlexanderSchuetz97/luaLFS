--
-- Copyright Alexander Schütz, 2021
--
-- This file is part of luaLFS.
--
-- luaLFS is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- luaLFS is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
--
-- A copy of the GNU Lesser General Public License should be provided
-- in the COPYING & COPYING.LESSER files in top level directory of luaLFS.
-- If not, see <https://www.gnu.org/licenses/>.
--

local package = require("package")

if type(package.loaded.lfs) == "table" then
    return package.loaded.lfs
end

local os = require("os")

if not os.execute or not os.date or not os.remove or not os.tmpname then
    error("missing required functions in os library")
end



local io = require("io")

if not io.open then
    error("missing required functions in io library")
end

local string = require("string")
local io_open = io.open
local os_remove = os.remove
local dofile_ = dofile
local loadfile_ = loadfile


local unix = false
local pathSeperator = "\\"
local pwdCommand = "echo %cd%"


-- simple unix detection
local dev_null = io.open("/dev/null", "r")
if dev_null then
    pwdCommand = "pwd"
    pathSeperator = "/"
    dev_null:close()
    unix = true
end

local lfs = {}
lfs["_VERSION"] = "1.8.0" -- for computability
lfs["_VERSION_LUALFS"] = "0.1.3" -- to distinguish
lfs["_DESCRIPTION"] = "luaLFS is library compatible to LuaFileSystem using linux system commands instead of native libraries"
lfs["_COPYRIGHT"] = "Copyright (C) 2021 Alexander Schütz"


local runCommand = nil
local pwd = nil
local exists = nil
local isDir = nil
local normalizePath = nil
local dirInternal = nil


--------------------------------------------------------------------------------------
-- GLOBAL UTILITY
--------------------------------------------------------------------------------------

local function leftPad(str, len, padding)
    len = len - string.len(str)
    if len <= 0 then
        return str
    end

    return string.rep(padding, len) .. str
end


function splitString(str, pat)
    local t = {}
    while true do
        local index, indexEnd = string.find(str, pat)
        if not index then
            t[#t+1] = str
            return t
        end

        t[#t+1] = string.sub(str, 1, index-1)
        str = string.sub(str, indexEnd+1)
    end
end

local function trimLeadingSpaces(value)
    while string.find(value, " ") == 1 do
        value = string.sub(value, 2)
    end

    return value
end

local function toAbsolutePath(path)
    if type(path) ~= "string" and type(path)  ~= "number" then
        return nil
    end

    local ts = tostring(path)


    if unix then
        if string.sub(ts, 1, 1) ~= '/' then
            ts = pwd .. ts
        end
    else
        if string.sub(ts, 2, 3) ~= ':\\' then
            ts = pwd .. ts
        end
    end


    return ts
end

--------------------------------------------------------------------------------------
-- Unix
--------------------------------------------------------------------------------------
if unix then
    runCommand = function(command)
        local path_script = os.tmpname()
        local path_out = os.tmpname()
        local path_err = os.tmpname()
        local path_sh = os.tmpname()


        local file = io_open(path_script, "w+")
        file:write("#!/bin/bash\n" .. command)
        file:close()

        local file2 = io_open(path_sh, "w+")
        file2:write("#!/bin/bash\nbash " .. path_script .. ' > ' .. path_out .. ' 2> ' .. path_err)
        file2:close()

        local exit = os.execute("bash " .. path_sh)

        local stdout_file = io_open(path_out)
        local stdout = stdout_file:read("*a")

        local stderr_file = io_open(path_err)
        local stderr = stderr_file:read("*a")

        stdout_file:close()
        stderr_file:close()


        os_remove(path_script)
        os_remove(path_out)
        os_remove(path_err)
        os_remove(path_sh)

        return exit, stdout, stderr
    end

    --Unix only
    local function assignPathVariable(variable, path)
        return variable .. "=$'" .. string.gsub(path, "'","\\'") .. "'\n"
    end

    --Unix only
    local function runSinglePathCommand(path, command)
        local exit, stdout, stderr = runCommand(assignPathVariable("x", path) .. "LANG=C " .. command .. " \"$x\"")
        if exit then
            return stdout
        end

        return nil, stderr
    end



    exists = function(path)
        if path == nil then
            return false
        end
        local res, err = runSinglePathCommand(path, "stat --printf %F")

        if not res then
            return false
        end
        return res ~= ""
    end



    isDir = function(path)
        if path == nil then
            return false
        end
        local res, err = runSinglePathCommand(path, "stat --printf %F")
        if not res then
            return false
        end
        return res == "directory"
    end


    normalizePath = function(path)
        if path == nil then
            return nil
        end
        local res, err = runSinglePathCommand(path, "readlink -n -m")
        if not res then
            return path
        end

        return res
    end

    -- parses output of ls -la
    dirInternal = function(path)
        local cmd, err = runSinglePathCommand(path, "ls -la")
        if not cmd then
            return nil, err
        end
        local lines = splitString(cmd, "\n")

        --ls command ends with "empty" line
        if lines[#lines] == "" then
            lines[#lines] = nil
        end

        local res = {}

        --skip the first line as it contains generic info we dont care about
        local i = 2
        while i <= #lines do
            local line = lines[i]
            local resultLine = {}
            local x = nil

            x = string.find(line, " ")
            resultLine.permissions = string.sub(line, 1, x-1)
            line = string.sub(line, x)
            line = trimLeadingSpaces(line)


            x = string.find(line, " ")
            resultLine.links = string.sub(line, 1, x-1)
            line = string.sub(line, x)
            line = trimLeadingSpaces(line)

            x = string.find(line, " ")
            resultLine.user = string.sub(line, 1, x-1)
            line = string.sub(line, x)
            line = trimLeadingSpaces(line)

            x = string.find(line, " ")
            resultLine.group = string.sub(line, 1, x-1)
            line = string.sub(line, x)
            line = trimLeadingSpaces(line)

            x = string.find(line, " ")
            resultLine.size = string.sub(line, 1, x-1)
            line = string.sub(line, x)
            line = trimLeadingSpaces(line)

            x = string.find(line, " ")
            resultLine.month = string.sub(line, 1, x-1)
            line = string.sub(line, x)
            line = trimLeadingSpaces(line)

            x = string.find(line, " ")
            resultLine.day = string.sub(line, 1, x-1)
            line = string.sub(line, x)
            line = trimLeadingSpaces(line)

            x = string.find(line, " ")
            resultLine.time = string.sub(line, 1, x-1)
            line = string.sub(line, x)
            line = trimLeadingSpaces(line)

            if string.find(line, "'") then
                line = string.sub(2, #line-1)
            end

            resultLine.name = line
            res[#res+1] = resultLine
            i = i + 1
        end

        return res
    end

    --------------------------------------------------------------------------------------
    -- FILE ATTRIBUTES Linux
    --------------------------------------------------------------------------------------

    --follow sym links
    local attributeStat = {}
    attributeStat.dev = "stat -L --printf %d"
    attributeStat.rdev = "stat -L --printf %t"
    attributeStat.ino = "stat -L --printf %i"
    attributeStat.mode = "stat -L --printf %F"
    attributeStat.nlink = "stat -L --printf %h"
    attributeStat.uid = "stat -L --printf %u"
    attributeStat.gid = "stat -L --printf %g"
    attributeStat.access = "stat -L --printf %X"
    attributeStat.modification = "stat -L --printf %Y"
    attributeStat.change = "stat -L --printf %Z"
    attributeStat.size = "stat -L --printf %s"
    attributeStat.permissions = "stat -L --printf %A"
    attributeStat.blocks = "stat -L --printf %b"
    attributeStat.blksize = "stat -L --file-system --printf %s"


    -- do not follow symlinks
    local symLinkAttributeStat = {}
    symLinkAttributeStat.dev = "stat --printf %d"
    symLinkAttributeStat.rdev = "stat --printf %t"
    symLinkAttributeStat.ino = "stat --printf %i"
    symLinkAttributeStat.mode = "stat --printf %F"
    symLinkAttributeStat.nlink = "stat --printf %h"
    symLinkAttributeStat.uid = "stat --printf %u"
    symLinkAttributeStat.gid = "stat --printf %g"
    symLinkAttributeStat.access = "stat --printf %x"
    symLinkAttributeStat.modification = "stat --printf %Y"
    symLinkAttributeStat.change = "stat --printf %z"
    symLinkAttributeStat.size = "stat --printf %s"
    symLinkAttributeStat.permissions = "stat --printf %A"
    symLinkAttributeStat.blocks = "stat --printf %b"
    symLinkAttributeStat.blksize = "stat --file-system --printf %s"

    --internal function tab parameter is one of the 2 tables passed above
    local function attrInternal(path, param2, tab)
        path = toAbsolutePath(path)

        if not exists(path) then
            return nil, "cannot obtain information from file '" .. path .. "': No such file or directory"
        end

        if type(param2) == "string" then
            if not tab[param2] then
                error("invalid attribute name '" .. param2 .. "'")
            end
            local res, err = runSinglePathCommand(path, tab[param2])
            if not res then
                return nil, err
            end

            return res
        end

        local result = nil
        if type(param2) == "table" then
            result = param2
        else
            result = {}
        end

        for i,v in pairs(tab) do
            local res, err = runSinglePathCommand(path, v)
            if not res then
                return nil, err
            end

            result[i] = res
        end

        return result
    end

    lfs.attributes = function(path, param2)
        return attrInternal(path, param2, attributeStat)
    end

    lfs.symlinkattributes = function(path, param2)
        return attrInternal(path, param2, symLinkAttributeStat)
    end

    --------------------------------------------------------------------------------------
    -- FILE MODIFICATION Linux
    --------------------------------------------------------------------------------------

    lfs.rmdir = function(path)
        path = toAbsolutePath(path)
        if not isDir(path) then
            return nil, "No such file or directory"
        end

        local res, err = runSinglePathCommand(path, "rm -rf")

        if res then
            return true
        end

        return nil, err
    end

    lfs.mkdir = function(path)
        path = toAbsolutePath(path)
        if exists(path) then
            return nil, "file or directory with this name already exists"
        end

        local res, err = runSinglePathCommand(path, "mkdir")

        if res then
            return true
        end

        return nil, err
    end

    lfs.link = function(linksrc, linkdst, symbolic)
        linksrc = toAbsolutePath(linksrc)
        linkdst = toAbsolutePath(linkdst)
        if not exists(linksrc) then
            return nil, "link source does not exist"
        end

        if exists(linkdst) then
            return nil, "link destination does already exist"
        end

        local exit, res, err = nil
        if symbolic then
            exit, res, err = runCommand(assignPathVariable("x", linksrc) .. assignPathVariable("y", linkdst), "LANG=C ln -s \"$x\" \"$y\"")
        else
            exit, res, err = runCommand(assignPathVariable("x", linksrc) .. assignPathVariable("y", linkdst), "LANG=C ln \"$x\" \"$y\"")
        end

        if exit then
            return true
        end
        return nil, err
    end

    lfs.touch = function(path, atime, mtime)
        path = toAbsolutePath(path)
        if not exists(path) then
            return nil, "No such file or directory"
        end

        local atimeT = os.date("*t", atime)
        local mtimeT = os.date("*t", mtime)


        -- touch --help for more info
        local atimeS = atimeT.year .. leftPad(tostring(atimeT.month), 2, "0") .. leftPad(tostring(atimeT.day), 2, "0") .. leftPad(tostring(atimeT.hour), 2, "0") .. leftPad(tostring(atimeT.min), 2, "0") .. "." .. leftPad(tostring(atimeT.sec), 2, "0")
        local mtimeS = mtimeT.year .. leftPad(tostring(mtimeT.month), 2, "0") .. leftPad(tostring(mtimeT.day), 2, "0") .. leftPad(tostring(mtimeT.hour), 2, "0") .. leftPad(tostring(mtimeT.min), 2, "0") .. "." .. leftPad(tostring(mtimeT.sec), 2, "0")

        local res, err = nil

        res, err = runSinglePathCommand(path, "touch -a -t " .. atimeS)

        if not res then
            return nil, err
        end

        res, err = runSinglePathCommand(path, "touch -m -t " .. mtimeS)

        if not res then
            return nil, err
        end

        return true
    end

end

--------------------------------------------------------------------------------------
-- Windows
--------------------------------------------------------------------------------------

if not unix then
    runCommand = function(command)
        local path_script = string.sub(os.tmpname(), 2) .. ".bat"
        local path_out = string.sub(os.tmpname(), 2)


        local file = io_open(path_script, "w+")
        file:write("@echo off\n" .. command)
        file:close()

        local exit = os.execute(path_script .. " > " .. path_out)

        local stdout_file = io_open(path_out)
        local stdout = stdout_file:read("*a")
        stdout_file:close()

        os_remove(path_script)
        os_remove(path_out)

        return exit, stdout, ""
    end

    --Windows only
    local function isWindowsPathValid(path)
        if path == nil then
            return false
        end

        if string.find(path, "*") then
            return false
        end

        if string.find(path, '"') then
            return false
        end

        return true
    end


    --Windows only
    local function parseWindowsTabularDate(out, token)

        local findex, fend = string.find(out, token)

        if not findex then
            return nil
        end

        out = string.sub(out, fend+1)



        findex, fend = string.find(out, ":")
        if not findex then
            return nil
        end

        out = string.sub(out, fend+1)
        out = trimLeadingSpaces(out)



        findex, fend = string.find(out, "\n")

        if findex then
            out = string.sub(out, 1, findex-1)
        end


        if string.len(out) ~= 19 then
            return nil
        end

        local date = {}

        date.day = tonumber(string.sub(out, 1, 2))
        date.month = tonumber(string.sub(out, 4, 5))
        date.year = tonumber(string.sub(out, 7, 10))
        date.hour = tonumber(string.sub(out, 12, 13))
        date.minute = tonumber(string.sub(out, 15, 16))
        date.second = tonumber(string.sub(out, 18, 19))

        if date.day == nil or date.month == nil or date.year == nil or date.hour == nil or date.minute == nil or date.second == nil then
            return nil
        end

        return date
    end

    exists = function(path)
        if not isWindowsPathValid(path) then
            return false
        end
        local res, out = runCommand([[powershell "Resolve-Path -Path \"]] .. path .. [[\""]])

        if not res then
            return false
        end

        local spt = splitString(out, "\n")
        if not spt[2] == "Path" then
            return false
        end

        return true
    end

    isDir = function(path)
        if not isWindowsPathValid(path) then
            return false
        end
        local res, out = runCommand([[powershell "Get-Item \"]] .. path .. [[\" | Format-List Mode"]])

        if not res then
            return false
        end

        if string.find(out, [[Mode : d]]) then
            return true
        end

        return false
    end

    normalizePath = function(path)
        local res, out = runCommand([[powershell "Resolve-Path -Path \"]] .. path .. [[\""]])
        if not res then
            return path
        end

        local spt = splitString(out, "\n")
        if not spt[2] == "Path" then
            return path
        end

        return spt[4]
    end


    dirInternal = function(path)
        if not isDir(path) then
            return nil, "no such directory"
        end

        local res, out = runCommand([[dir /B "]] .. path .. [["]])
        if not res then
            return nil, out
        end


        local res = {}
        res[1] = {["name"] = "."}
        res[2] = {["name"] = ".."}

        local spt = splitString(out, "\n")
        for i,v in ipairs(spt) do
            if string.len(v) == 0 then
                break;
            end

            res[#res+1] = {["name"] = v}
        end

        return res
    end

    --------------------------------------------------------------------------------------
    -- FILE ATTRIBUTES Windows
    --------------------------------------------------------------------------------------

    local attributeStat = {}
    attributeStat.dev = function(path)
        -- "todo improve"
        return string.sub(path, 1, 1)
    end
    attributeStat.rdev = attributeStat.dev
    attributeStat.ino = function(path)
        return 0
    end
    attributeStat.mode = function(path)
        if isDir(path) then
            return "directory"
        end

        return "file"
    end
    attributeStat.nlink = function(path)
        return 0
    end
    attributeStat.uid = function(path)
        return 0
    end
    attributeStat.gid = function(path)
        return 0
    end

    attributeStat.access = function(path)

        local res, out = runCommand([[powershell "Get-Item \"]] .. path .. [[\" | Format-List LastAccessTime"]])

        if not res then
            return 0
        end

        local d = parseWindowsTabularDate(out, "LastAccessTime")
        if not d then
            return 0
        end

        return os.time(d)
    end
    attributeStat.modification = function(path)

        local res, out = runCommand([[powershell "Get-Item \"]] .. path .. [[\" | Format-List LastWriteTime"]])

        if not res then
            return 0
        end

        local d = parseWindowsTabularDate(out, "LastWriteTime")
        if not d then
            return 0
        end

        return os.time(d)
    end
    attributeStat.change = attributeStat.modification

    attributeStat.size = function(path)
        local res, out = runCommand([[set file="]] .. path .. [["
		FOR /F "usebackq" %%A IN ('%file%') DO @ECHO %%~zA]])

        if not res then
            return 0
        end

        local num = tonumber(out)
        if not num then
            return 0
        end

        return num
    end

    attributeStat.permissions = function()
        --todo
        return ""
    end

    attributeStat.blocks = function(path)
        return 0
    end
    attributeStat.blksize = function(path)
        return 0
    end


    lfs.attributes = function(path, param2)
        path = toAbsolutePath(path)

        if not exists(path) then
            return nil, "cannot obtain information from file '" .. path .. "': No such file or directory"
        end

        if type(param2) == "string" then
            if not attributeStat[param2] then
                error("invalid attribute name '" .. param2 .. "'")
            end

            return attributeStat[param2](path)
        end

        local result = nil
        if type(param2) == "table" then
            result = param2
        else
            result = {}
        end

        for i,v in pairs(attributeStat) do
            result[i] = v(path)
        end

        return result
    end

    lfs.symlinkattributes = function(path, param2)
        -- well this is windows we can be happy if windows even knows what a link is.
        return lfs.attributes(path, param2)
    end

    --------------------------------------------------------------------------------------
    -- FILE MODIFICATION Windows
    --------------------------------------------------------------------------------------
    lfs.rmdir = function(path)
        path = toAbsolutePath(path)
        if not isDir(path) then
            return nil, "No such file or directory"
        end

        local res, err = runCommand("rmdir /S /Q \"" .. path .. "\"")

        if res then
            return true
        end

        return nil, err
    end

    lfs.mkdir = function(path)
        path = toAbsolutePath(path)
        if exists(path) then
            return nil, "file or directory with this name already exists"
        end

        local res, err = runCommand("mkdir \"" .. path .. "\"")

        if res then
            return true
        end

        return nil, err
    end

    lfs.link = function(linksrc, linkdst, symbolic)
        linksrc = toAbsolutePath(linksrc)
        linkdst = toAbsolutePath(linkdst)
        if not exists(linksrc) then
            return nil, "link source does not exist"
        end

        if exists(linkdst) then
            return nil, "link destination does already exist"
        end

        local arg = ""
        if isDir(linksrc) then
            arg = "/D "
        end

        local exit, res, err = nil
        if symbolic then
            exit, res = runCommand("mklink " .. arg .. "\"" .. "\"")
        else
            exit, res = runCommand("mklink /H" .. arg .. "\"" .. "\"")
        end

        if exit then
            return true
        end
        return nil, res
    end

    local months = {}
    months[1] = " January "
    months[2] = " February "
    months[3] = " March "
    months[4] = " April "
    months[5] = " May "
    months[6] = " June "
    months[7] = " July "
    months[8] = " August "
    months[9] = " September "
    months[10] = " October "
    months[11] = " November "
    months[12] = " December "

    lfs.touch = function(path, atime, mtime)
        path = toAbsolutePath(path)
        if not exists(path) then
            return nil, "No such file or directory"
        end

        local atimeT = os.date("*t", atime)
        local mtimeT = os.date("*t", mtime)


        local atimeS = leftPad(tostring(atimeT.day), 2, "0") .. months[atimeT.month] .. atimeT.year .. " " .. leftPad(tostring(atimeT.hour), 2, "0") .. ":" .. leftPad(tostring(atimeT.min), 2, "0") .. ":" .. leftPad(tostring(atimeT.sec), 2, "0")
        local mtimeS = leftPad(tostring(mtimeT.day), 2, "0") .. months[mtimeT.month] .. mtimeT.year .. " " .. leftPad(tostring(mtimeT.hour), 2, "0") .. ":" .. leftPad(tostring(mtimeT.min), 2, "0") .. ":" .. leftPad(tostring(mtimeT.sec), 2, "0")

        local res, err = nil

        res, err = runCommand([[powershell "(Get-Item \"]] .. path .. [[\").LastWriteTime=("]] .. mtimeS .. [[")]])

        if not res then
            return nil, err
        end

        res, err = runCommand([[powershell "(Get-Item \"]] .. path .. [[\").LastAccessTime=("]] .. atimeS .. [[")]])

        if not res then
            return nil, err
        end

        return true
    end
end

--------------------------------------------------------------------------------------
-- LISTING+NAVIGATION
--------------------------------------------------------------------------------------

--lua iterator over dirInternal
lfs.dir = function(path)
    local ts = toAbsolutePath(path)

    if not ts then
        return nil, "invalid path"
    end

    local listing, err = dirInternal(ts)

    if not listing then
        return nil, err
    end

    -- this is userdata in luafilesystem so type() of this will return "table" instead of "userdata". Nothing we can do about it...
    local dir_object = {}
    dir_object["__index"] = 1
    dir_object["__listing"] = listing
    dir_object["next"] = function(self)
        if not self["__listing"] then
            return nil
        end

        local v = self["__listing"][self["__index"]]
        if not v then
            self["__listing"] = nil
            return nil
        end

        self["__index"] = self["__index"] + 1
        return v.name
    end

    dir_object ["close"] = function(self)
        self["__listing"] = nil
    end

    return function(myDir)
        return myDir:next()
    end, dir_object
end


lfs.currentdir = function()
    return pwd
end

lfs.chdir = function(path)
    local ts = toAbsolutePath(path)

    if not ts then
        return nil, "invalid path"
    end

    if isDir(ts) then
        pwd = normalizePath(ts) .. pathSeperator
        return true
    else
        return nil, "no such directory " .. ts
    end
end

--------------------------------------------------------------------------------------
-- UNSUPPORTED FUNCTIONS
--------------------------------------------------------------------------------------

lfs.lock_dir = function(...)
    return nil, "Function 'lock_dir' not provided by implementation"
end

lfs.lock = function(...)
    return nil, "Function 'lock' not provided by implementation"
end

lfs.unlock = function(...)
    return nil, "Function 'unlock' not provided by implementation"
end

lfs.setmode = function(...)
    --NOOP
end

--------------------------------------------------------------------------------------
-- INIT
--------------------------------------------------------------------------------------

local exit, err = nil
exit, pwd, err = runCommand(pwdCommand)
if not exit then
    error("failed to get pwd " .. err)
end

--remove trailing \n and add / (or \)
pwd = string.sub(pwd, 1, string.len(pwd)-1) .. pathSeperator

--------------------------------------------------------------------------------------
-- OVERWRITING
--------------------------------------------------------------------------------------

package.loaded.lfs = lfs
--Overwrite io.open to use relative paths...

io.open = function(path, ...)
    path = toAbsolutePath(path)
    return io_open(path, ...)
end

--Overwrite os.remove to use relative paths...
os.remove = function(path)
    path = toAbsolutePath(path)
    return os_remove(path)
end

dofile = function(file)
    local npath = toAbsolutePath(file)
    if exists(npath) then
        return dofile_(npath)
    end

    return dofile_(file)
end

loadfile = function(file, ...)
    local npath = toAbsolutePath(file)
    if exists(npath) then
        return loadfile_(npath)
    end

    return loadfile_(file)
end



return lfs