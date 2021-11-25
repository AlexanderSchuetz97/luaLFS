//
// Copyright Alexander Schütz, 2021
//
// This file is part of luaLFS.
//
// luaLFS is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// luaLFS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Lesser General Public License for more details.
//
// A copy of the GNU Lesser General Public License should be provided
// in the COPYING & COPYING.LESSER files in top level directory of luaLFS.
// If not, see <https://www.gnu.org/licenses/>.
//
package io.github.alexanderschuetz97.lualfs;

import org.luaj.vm2.Globals;
import org.luaj.vm2.LuaValue;
import org.luaj.vm2.lib.TwoArgFunction;

/**
 * Java wrapper for lfs.lua
 */
public class LuaLFSLib extends TwoArgFunction {

    @Override
    public LuaValue call(LuaValue arg1, LuaValue arg2) {
        Globals globals = arg2.checkglobals();
        LuaValue lfs = ScriptLoader.instance().load(globals, "lfs.lua").call();
        return lfs;
    }
}
