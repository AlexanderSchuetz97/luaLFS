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

import org.luaj.vm2.Globals;
import org.luaj.vm2.LuaError;
import org.luaj.vm2.LuaFunction;
import org.luaj.vm2.LuaValue;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * Utility to load the precompiled lua scripts.
 * Those scripts are loaded from java bytecode unless a debugLib is present.
 * Presence of a debugLib forces recompilation using globals.compiler.
 */
public class ScriptLoader {

    private static ScriptLoader instance;

    private final Map<String, Class<? extends LuaFunction>> loaded = new HashMap<>();

    public static synchronized ScriptLoader instance() {
        if (instance == null) {
            instance = new ScriptLoader();
        }
        return instance;
    }

    public static void setInstance(ScriptLoader loader) {
        instance = loader;
    }

    public ScriptLoader() {
        init();
    }

    protected ClassLoader getClassLoader() {
        InputStream url = ScriptLoader.class.getResourceAsStream("/lualfs/compiled.zip");
        if (url == null) {
            throw new LuaError("resource /lualfs/compiled.zip is missing");
        }

        Map<String, byte[]> files;
        try {
            files = readZipFile(url);
        } catch (Exception exc) {
            throw new LuaError("Error reading resource /lualfs/compiled.zip");
        }


        return new BACL(files);
    }

    protected static class BACL extends ClassLoader {

        private final Map<String, byte[]> files;

        public BACL(Map<String, byte[]> files) {
            super(ScriptLoader.class.getClassLoader());
            this.files = files;
        }

        @Override
        public Class findClass(String classname) throws ClassNotFoundException {
            //We dont have directories in the zip so this should be fine...
            byte[] bytes = files.get(classname+".class");
            if (bytes != null) {
                return defineClass(classname, bytes, 0, bytes.length);
            }
            return super.findClass(classname);
        }
    }

    protected void init() {
       ClassLoader urlClassLoader = getClassLoader();
        try {
            loaded.put("lfs.lua", (Class<? extends LuaFunction>) Class.forName("lfs", true, urlClassLoader));
        } catch (Exception e) {
            throw new LuaError("Failed to load precompiled lua scripts from jar " + e.getClass().getName() + " " + e.getMessage());
        }
    }



    public LuaValue load(Globals globals, String aScript) {
        if (globals.debuglib != null) {
            InputStream in = ScriptLoader.class.getResourceAsStream("/lualfs/" +aScript);

            if (in == null) {
                throw new LuaError("resource /lualfs/" + aScript + " is missing");
            }

            String script = null;
            try {
                script = new String(readAllBytesFromInputStream(in), StandardCharsets.UTF_8);
            } catch (IOException e) {
                throw new LuaError("Error reading resource /lualfs/" + aScript);
            }

            return globals.load(script, aScript, globals);
        }

        Class<? extends LuaFunction> clazz = loaded.get(aScript);
        if (clazz == null) {
            throw new LuaError("Script " + aScript + " not found");
        }

        try {
            LuaFunction function = clazz.newInstance();
            function.initupvalue1(globals);
            return function;
        } catch (Exception e) {
            throw new LuaError("Error loading " + aScript + " " + e.getClass().getName() + " " + e.getMessage());
        }
    }

    protected static Map<String, byte[]> readZipFile(InputStream zip) throws IOException {
        Map<String, byte[]> files = new HashMap<>();

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        byte[] buffer = new byte[512];

        try (ZipInputStream zipInput = new ZipInputStream(zip)) {
            while (true) {
                ZipEntry entry = zipInput.getNextEntry();
                if (entry == null) {
                    return files;
                }

                baos.reset();
                int i = 0;
                while (i != -1) {
                    i = zipInput.read(buffer);
                    if (i > 0) {
                        baos.write(buffer, 0, i);
                    }
                }

                files.put(entry.getName(), baos.toByteArray());
                zipInput.closeEntry();
            }
        }
    }

    protected static byte[] readAllBytesFromInputStream(InputStream inputStream) throws IOException {
        byte[] buf = new byte[512];
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        int i = 0;
        while(i != -1) {
            i = inputStream.read(buf);
            if (i > 0) {
                baos.write(buf, 0, i);
            }
        }

        return baos.toByteArray();
    }
}
