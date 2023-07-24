use std::collections::HashMap;

use crate::errors::Errcode;
use crate::config::ContainerOpts;

pub type Environment = HashMap<String, String>;

pub fn generate_child_environment(config: &ContainerOpts) -> Result<Environment, Errcode> {
    let mut env = HashMap::new();

    if config.export_display_env {
        export_display_env(&mut env)?;
    }
    for key in config.add_env_export.iter() {
        log::debug!("Exporting env var {key}");
        export_env(key, &mut env);
    }
    Ok(env)
}

fn export_display_env(env: &mut Environment) -> Result<(), Errcode> {
    log::debug!("Exporting display environment");
    export_env("DISPLAY", env);
    export_env("WAYLAND_DISPLAY", env);
    export_env("XDG_SESSION_TYPE", env);
    export_env("XDG_RUNTIME_DIR", env);
    export_env("XDG_CURRENT_DESKTOP", env);
    Ok(())
}

fn export_env<T: ToString>(key: T, env: &mut Environment) {
    if let Some(val) = std::env::var_os(key.to_string()) {
        env.insert(key.to_string(), val.into_string().unwrap());
    } else {
        log::debug!("Env var {} not found", key.to_string());
    }
}
