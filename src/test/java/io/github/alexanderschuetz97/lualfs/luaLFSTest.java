//
// Copyright Alexander Schütz, 2021
//
// This file is part of luaLFS.
//
// luaLFS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// luaLFS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// A copy of the GNU General Public License should be provided
// in the COPYING file in top level directory of luaLFS.
// If not, see <https://www.gnu.org/licenses/>.
//
package io.github.alexanderschuetz97.lualfs;

import org.junit.Assert;
import org.junit.Test;
import org.luaj.vm2.Globals;
import org.luaj.vm2.LuaError;
import org.luaj.vm2.LuaValue;
import org.luaj.vm2.Varargs;
import org.luaj.vm2.lib.jse.JsePlatform;

import java.io.File;
import java.io.FileDescriptor;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.RandomAccessFile;
import java.nio.channels.FileLock;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class luaLFSTest {

    private Globals globals;

    public LuaValue mkGlobals() {
        ScriptLoader.setInstance(new ScriptLoader() {
            protected ClassLoader getClassLoader() {


                Map<String, byte[]> files;
                try {
                    InputStream url = new FileInputStream("target/luajcoutput/compiled.zip");
                    if (url == null) {
                        throw new LuaError("target/luajcoutput/compiled.zip");
                    }

                    files = readZipFile(url);
                } catch (Exception exc) {
                    throw new LuaError("Error reading target/luajcoutput/compiled.zip");
                }


                return new BACL(files);
            }
        });
        globals = JsePlatform.standardGlobals();
        globals.load(new LuaLFSLib());
        return globals.load("return require(\"lfs\")").call();
    }

    @Test
    public void testMisc() throws IOException {
        LuaValue value = mkGlobals();
        String pwd = value.get("currentdir").call().checkjstring();
        Assert.assertTrue(pwd.endsWith("/luaLFS/"));
        value.get("chdir").call("src/test/java/TestFolder");
        pwd = value.get("currentdir").call().checkjstring();
        Assert.assertTrue(pwd.endsWith("/luaLFS/src/test/java/TestFolder/"));
        Varargs args = value.get("dir").invoke(LuaValue.valueOf("."));

        List<String> entries = new ArrayList<>();
        LuaValue ndir;
        while(!(ndir = args.arg(2).method("next")).isnil()) {
            entries.add(ndir.checkjstring());
        }

        LuaValue table = value.get("attributes").call("tt3");
        Assert.assertTrue(table.istable());
        Assert.assertFalse(table.get("dev").isnil());
        Assert.assertFalse(table.get("ino").isnil());
        Assert.assertTrue(table.get("mode").checkjstring().equals("directory"));
        Assert.assertFalse(table.get("uid").isnil());
        Assert.assertFalse(table.get("gid").isnil());
        Assert.assertFalse(table.get("rdev").isnil());
        Assert.assertTrue(table.get("access").isnumber());
        Assert.assertTrue(table.get("modification").isnumber());
        Assert.assertTrue(table.get("change").isnumber());
        Assert.assertFalse(table.get("permissions").isnil());
        Assert.assertTrue(table.get("size").isnumber());
        Assert.assertTrue(table.get("blocks").isnumber());
        Assert.assertTrue(table.get("blksize").isnumber());

        table = value.get("attributes").call("tt2");
        Assert.assertTrue(table.istable());
        Assert.assertFalse(table.get("dev").isnil());
        Assert.assertFalse(table.get("ino").isnil());
        Assert.assertTrue(table.get("mode").checkjstring().equals("regular file"));
        Assert.assertFalse(table.get("uid").isnil());
        Assert.assertFalse(table.get("gid").isnil());
        Assert.assertFalse(table.get("rdev").isnil());
        Assert.assertTrue(table.get("access").isnumber());
        Assert.assertTrue(table.get("modification").isnumber());
        Assert.assertTrue(table.get("change").isnumber());
        Assert.assertFalse(table.get("permissions").isnil());
        Assert.assertTrue(table.get("size").isnumber());
        Assert.assertTrue(table.get("blocks").isnumber());
        Assert.assertTrue(table.get("blksize").isnumber());
        Assert.assertEquals(10, table.get("size").toint());


    }
}
