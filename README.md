# luaLFS
luaLFS is a library compatible to LuaFileSystem using unix system commands instead of native c libraries.

The primary focus of this implementation is to provide easy integration of scripts that use lfs/LuaFileSystem in linux/unix environments
where LuaFileSystem cannot be easily installed. This includes but is not limited to Java applications using LuaJ.

If your application/environment has no such constraints then I do not recommend using luaLFS.<br>
Use LuaFileSystem instead: https://github.com/keplerproject/luafilesystem/

## License
luaLFS is released under the GNU General Public License Version 3. <br>
A copy of the GNU General Public License Version 3 can be found in the COPYING file.<br>

## Requirements
As implied in the description this library will only function on linux or other unix systems provided they
have the same system commands available. The following commands are used by luaLFS:
- pwd (initially to determine work directory)
- bash (by all functions)
- stat (by all functions)
- readlink (by all functions)
- mkdir (by lfs.mkdir)
- rm (by lfs.rmdir)
- ls (by lfs.dir)
- touch (by lfs.touch)

#### Windows
Windows is currently not supported at all.<br>
luaLFS may still be relevant to you even if your scripts have to support windows since you can also
load luaLFS in a way that it only loads when c based LuaFileSystem is not installed. This may allow for easier deployment/usage on linx/unix machines 
and will not change any requirements for windows machines. See the below for an example on how to do this.

## Limitations
The C based LFS implementation by LuaFileSystem should be preferred since it is faster than luaLFS.

The error messages returned by LuaFileSystem and luaLFS are not identical in all cases. <br>
LuaLFS returns stderr from the unix programs it runs when an error occurs <br>
LuaFileSystem returns strerror(errno) from GLIBC. 

From all functions that the original LuaFileSystem library offers only the following 3 functions cannot be implemented
using standard linux system commands:

- lfs.lock_dir
- lfs.lock
- lfs.unlock

When called these functions will always return nil followed by
"Function 'xxx' not provided by implementation"

C based LFS calls "chdir" when changing the work directory. This changes the work directory of the entire process. 
LuaLFS does cannot do this and instead keeps the work directory in a variable separated from the actual work directory of the process. 
io.open, os.remove, dofile, loadfile are overwritten to use the work directory from luaLFS. 
If your scripts use other functions that rely on the work directory then they will not use the changed 
work directory.

## Usage
#### C/C++/Generic Lua:
The only file you need from this repository is "lfs.lua" which is in the "src/main/resources/lualfs" directory.

Download this file and place it next to your script or at your discretion in your lua path.

If you place the lfs.lua file next to your script file then the easiest way to load it
is by running it with "dofile":

````
dofile('lfs.lua')
local lfs = require('lfs')
for file in lfs.dir(".") do
    print(file)
end
````

#### Prefer C Based LuaFileSystem and only load luaLFS as a fallback:

luaLFS will first check if a module named 'lfs' is already loaded before doing anything. This allows for preloading c based LuaFileSystem and only using luaLFS as a fallback.
If you want to prefer the c based LFS implementation by LuaFileSystem, then I recommend the following approach:

````
-- this will load c based lfs if installed and ignore the error if not
pcall(require, 'lfs')

-- this will load lfs.lua which is a noop if c based lfs is loaded
-- keep in mind that you have to rename lfs.lua to some other file name
-- otherwise the first require may decide to "load" it instead of c based lfs.
-- You may choose whatever filename you desire except "lfs.lua"
dofile("luaLFS.lua")

-- this will return whichever implemention was actually loaded
local lfs = require('lfs')
for file in lfs.dir(".") do
    print(file)
end
````

#### Java/LuaJ:

This will require Java 7 or newer and LuaJ 3.0.1<br>
BCEL is not required. 

All scripts have already been precompiled to Java bytecode by LuaJC. <br>
The original lfs.lua is also included and only loaded when Globals.debugLib is set to allow for easier debugging.

Maven:
````
<dependency>
  <groupId>io.github.alexanderschuetz97</groupId>
  <artifactId>lualfs</artifactId>
  <version>0.1</version>
</dependency>
````

In Java:
````
Globals globals = JsePlatform.standardGlobals();
globals.load(new LuaLFSLib());
//.... (Standart LuaJ from this point)
globals.load(new InputStreamReader(new FileInputStream("test.lua")), "test.lua").call();
````
In test.lua:
````
local lfs = require('lfs')
for file in lfs.dir(".") do
    print(file)
end
````
#### How to compile luaLFS for Java
It is recommended to uncomment the maven-gpg-plugin section from the pom.xml
before building. Alternatively you may build it by passing "-Dgpg.skip" as a maven parameter.

If you do not want to run the junit tests then pass "-DskipTests"