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


import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;
import java.util.ArrayList;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

/**
 * Utility that compiles the luascript to java bytecode.
 * This is only needed during the build process.
 */
class ScriptPreCompiler {

    public static void main(String[] args) throws Throwable {
        File f = new File("target/deps");
        List<URL> urlList = new ArrayList<>();
        for (File dep : f.listFiles()) {
            if (dep.getName().contains("luaj") || dep.getName().contains("bcel")) {
                urlList.add(dep.toURI().toURL());
            }
        }

        URLClassLoader loader = new URLClassLoader(urlList.toArray(new URL[0]), ScriptPreCompiler.class.getClassLoader());
        Method luajc = Class.forName("luajc", true, loader).getDeclaredMethod("main", String[].class);


        luajc.invoke(null, new Object[]{new String[]{
                "-r",
                "-d",
                "target/luajcoutputclasses",
                "-v",
                "src/main/resources/lualfs",
        }});

        //Create the directory
        new File("target/luajcoutput").mkdir();
        File dest = new File("target/luajcoutput/compiled.zip");

        //Zip the compiled classes
        ZipOutputStream zipper = new ZipOutputStream(new FileOutputStream(dest));
        File src = new File("target/luajcoutputclasses");
        for (File compiled : src.listFiles()) {
            try (FileInputStream fais = new FileInputStream(compiled)) {
                zipper.putNextEntry(new ZipEntry(compiled.getName()));
                byte[] buf = new byte[512];
                int i = 0;
                while (i != -1) {
                    i = fais.read(buf);
                    if (i > 0) {
                        zipper.write(buf, 0, i);
                    }
                }
                zipper.closeEntry();
            }
        }
        zipper.close();

        //Test the bytecode of the classes
        URLClassLoader urlcl = new URLClassLoader(new URL[]{dest.toURI().toURL()}, loader);
        for (File compiled : src.listFiles()) {
            String name = compiled.getName();
            name = name.substring(0, name.length()-".class".length());
            Class.forName(name, true, urlcl);
        }
    }
}
