mod snapshot_config;

use std::{ffi::OsStr, fs::File, io::BufWriter, path::Path};

use codesnap::{themes, utils::path::parse_file_name};
use mlua::prelude::*;
use snapshot_config::SnapshotConfigLua;

fn save(_: &Lua, (file_path, config): (String, SnapshotConfigLua)) -> LuaResult<()> {
    let extension = Path::new(&file_path)
        .extension()
        .and_then(OsStr::to_str)
        .unwrap_or("png");
    let result = match extension {
        "svg" => config
            .0
            .create_snapshot()
            .and_then(|snapshot| snapshot.svg_data())
            .and_then(|data| data.save(&file_path)),
        "html" => config
            .0
            .create_snapshot()
            .and_then(|snapshot| snapshot.html_data())
            .and_then(|data| data.save(&file_path)),
        _ => {
            let path = parse_file_name(&file_path).map_err(mlua::Error::external)?;

            File::create(path)
                .map_err(Into::into)
                .and_then(|file| config.0.write_png(BufWriter::new(file)))
        }
    };

    result.map_err(|error| {
        mlua::Error::RuntimeError(format!("Failed to save snapshot to {file_path}: {error}"))
    })
}

fn copy(_: &Lua, config: SnapshotConfigLua) -> LuaResult<()> {
    config
        .0
        .create_snapshot()
        .and_then(|snapshot| snapshot.raw_data())
        .and_then(|data| data.copy())
        .map_err(mlua::Error::external)
}

fn copy_ascii(_: &Lua, config: SnapshotConfigLua) -> LuaResult<()> {
    config
        .0
        .create_ascii_snapshot()
        .and_then(|snapshot| snapshot.raw_data())
        .and_then(|data| data.copy())
        .map_err(mlua::Error::external)
}

fn save_ascii(_: &Lua, (file_path, config): (String, SnapshotConfigLua)) -> LuaResult<()> {
    config
        .0
        .create_ascii_snapshot()
        .and_then(|snapshot| snapshot.raw_data())
        .and_then(|data| data.save(&file_path))
        .map_err(mlua::Error::external)
}

fn parse_code_theme(_: &Lua, code_theme: String) -> LuaResult<String> {
    let rt = tokio::runtime::Runtime::new().map_err(mlua::Error::external)?;

    rt.block_on(themes::parse_code_theme(&code_theme))
        .map_err(mlua::Error::external)
}

#[mlua::lua_module(skip_memory_check)]
fn generator(lua: &Lua) -> LuaResult<LuaTable> {
    let exports = lua.create_table()?;

    exports.set("save", lua.create_function(save)?)?;
    exports.set("copy", lua.create_function(copy)?)?;
    exports.set("copy_ascii", lua.create_function(copy_ascii)?)?;
    exports.set("save_ascii", lua.create_function(save_ascii)?)?;
    exports.set("parse_code_theme", lua.create_function(parse_code_theme)?)?;

    Ok(exports)
}
