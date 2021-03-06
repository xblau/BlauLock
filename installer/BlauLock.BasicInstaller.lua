--[[

    This file is part of BlauLock, a ComputerCraft program
    that adds password protection on startup.

    Author: Daniel 'xBlau' Mosquera <daniel+github@blaudev.es>
    Repository: https://github.com/xblau/blaulock

    THIS FILE IS DISTRIBUTED UNDER THE TERMS OF THE MIT LICENSE

]]

local tArgs, Current = {...}, {}
local Version = 'stable'

if tArgs[1] ~= nil then
    print( "\nINFO: version set to '" .. tArgs[1] .. "'\n")
    Version = tArgs[1]
end

local function download( link, path )
    local handler = http.get( link )
    if handler then
        local data = handler.readAll()
        f = fs.open( path, "w" )
        f.write( data )
        f.close()
        return true
    else return false end
end

if fs.exists( '/.BlauLock' ) then
    if fs.isDir( '/.BlauLock' ) then
        print( 'ERROR: BlauLock is already installed!' )
        print( 'Run "blaulock-cmd remove" to uninstall first.' )
        return false
    end

    fs.delete( '/.BlauLock' )
end

if not http then error( 'HTTP API not found!' ) end

write( 'Fetching list of files...     ' )
local handler = http.get( 'https://raw.githubusercontent.com/xblau/blaulock/master/installer/files.dat' )

if not handler then
    print( 'Failed.' )
    error( 'files.dat download failed!' )
else
    print( 'Success.' )
    local sFiles = handler.readAll()
    Current['Files'] = textutils.unserialize( sFiles )
end

write( 'Validating target version...  ' )

if Version == 'stable' then
    Version = Current['Files']['stable']
end

if not Current['Files'][Version] then
    print( 'Failed.' )
    error( 'No files found for version "' .. Version .. '"!' )
else
    print( 'Success.')

    local handle = fs.open( '/.BlauLock/version', 'w' )
    if handle then
        handle.write( Version )
        handle.close()
    end

    Current['DownloadList'] = Current['Files'][Version]
end

local bOK = true
write( 'Downloading files (' .. Version .. ')... ' )

for i = 1, #Current['DownloadList'] do
    local try = download( Current['DownloadList'][i]['URL'], Current['DownloadList'][i]['Path'])
    if not try then
        bOK = false
    end
end

if not bOK then
    print( 'Failed.' )
    error( 'At least one download failed!' )
    fs.delete( '/.BlauLock' )
else
    print( 'Success.' )
end

print( 'Loading BlauLock\'s API...' )
dofile( '/.BlauLock/functions.lua' )
local BlauLock = dofile( '/.BlauLock/BlauLock.API.lua' )

local PasswordDefined = false

while not PasswordDefined do
    print('')

    write( 'New password: ' )
    local newpass = read( '*' )

    write( 'Confirm it: ' )
    local confpass = read( '*' )

    print('')

    if newpass == confpass then
        Current['Pass'] = newpass
        PasswordDefined = true
    else
        print( 'ERROR: passwords do not match!' )
    end
end

local NewConfig = { Enabled = true, }

print( 'Generating hash, please wait...' )

NewConfig['Hash'] = BlauLock.GenerateHash( 'SHA256', Current['Pass'], 15 )

psavetable( NewConfig, '/.BlauLock/config.dat' )

shell.setAlias( 'blaulock-cmd', '/.BlauLock/BlauLock.CMD.lua' )

if fs.exists( '/startup' ) then
    BlauLock.inject( '/startup', '/.BlauLock/BlauLock.Main.lua' )
else
    local file = fs.open( '/startup', 'w' )
    file.write( "shell.run('/.BlauLock/BlauLock.Main.lua')" )
    file.close()
end

print( 'Done! BlauLock is now installed and enabled.' )
print( 'You can manage it with the "blaulock-cmd" command.' )
