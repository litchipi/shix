use crate::config::ContainerOpts;
use crate::errors::Errcode;

use std::path::PathBuf;

// TODO    Set /host mountpoint as a constant / config var

use std::fs::create_dir_all;
pub fn create_directory(path: &PathBuf) -> Result<(), Errcode> {
    match create_dir_all(path) {
        Err(e) => {
            log::error!("Cannot create directory {}: {}", path.to_str().unwrap(), e);
            Err(Errcode::MountsError(2))
        }
        Ok(_) => Ok(()),
    }
}

pub fn mount_directory(
    path: Option<&PathBuf>,
    mount_point: &PathBuf,
    mount_type: &Option<String>,
    flags: Vec<MsFlags>,
) -> Result<(), Errcode> {
    let mut ms_flags = MsFlags::empty();
    for f in flags.iter() {
        ms_flags.insert(*f);
    }
    match mount(
        path,
        mount_point,
        mount_type.as_ref().map(|v| v.as_str()),
        ms_flags,
        None::<&PathBuf>,
    ) {
        Ok(_) => Ok(()),
        Err(e) => {
            if let Some(p) = path {
                log::error!(
                    "Cannot mount {} to {}: {}",
                    p.to_str().unwrap(),
                    mount_point.to_str().unwrap(),
                    e
                );
            } else {
                log::error!("Cannot remount {}: {}", mount_point.to_str().unwrap(), e);
            }
            Err(Errcode::MountsError(3))
        }
    }
}

pub fn create_symlink(src: &PathBuf, dst: &PathBuf) -> Result<(), Errcode> {
    let src: PathBuf = if src.starts_with("/") {
        src.strip_prefix("/").unwrap().into()
    } else {
        src.clone()
    };
    let src = PathBuf::from("/host").join(src);

    if let Some(p) = dst.parent() {
        if let Err(e) = std::fs::create_dir_all(p) {
            log::error!("Unable to create parent directory: {e:?}");
            return Err(Errcode::MountsError(6));
        }
    }
    if dst.is_symlink() {
        std::fs::remove_file(dst).unwrap();
    }
    if let Err(e) = nix::unistd::symlinkat(&src, None, dst) {
        log::error!("Unable to create symlink {dst:?}: {e:?}");
        return Err(Errcode::MountsError(7));
    }
    Ok(())
}

use nix::mount::{mount, MsFlags};
use nix::unistd::{chdir, chown, pivot_root, Gid, Uid};
pub fn setmountpoint(config: &ContainerOpts) -> Result<(), Errcode> {
    log::debug!("Setting mount points ...");
    mount_directory(
        None,
        &PathBuf::from("/"),
        &None,
        vec![MsFlags::MS_REC, MsFlags::MS_PRIVATE],
    )?;

    log::debug!(
        "Mounting root mount point {:?} to new root {:?}",
        config.root_mount_point,
        config.new_root
    );
    create_directory(&config.new_root)?;
    create_directory(&config.root_mount_point)?;
    mount_directory(
        Some(&config.root_mount_point),
        &config.new_root,
        &None,
        vec![MsFlags::MS_BIND, MsFlags::MS_PRIVATE],
    )?;

    let home_path = config.new_root.join("home").join(&config.username);
    create_directory(&home_path)?;
    chown(
        &home_path,
        Some(Uid::from_raw(config.uid_gid.0)),
        Some(Gid::from_raw(config.uid_gid.1)),
    )
    .unwrap();

    log::debug!("Mounting additionnal paths");
    for p in config.addpaths.iter() {
        p.add_to_root(&config.new_root)?;
    }

    log::debug!("Initializing filesystem");
    for (path, entry) in config.fs_init.iter() {
        entry.create(&config.new_root, path)?;
    }

    let put_old = config.new_root.join("host");
    create_directory(&put_old)?;

    log::debug!(
        "Pivoting root to {:?}, putting old root in {put_old:?}",
        config.new_root
    );
    if let Err(e) = pivot_root(&config.new_root, &put_old) {
        log::error!("Error while pivoting root: {e:?}");
        return Err(Errcode::MountsError(4));
    }

    log::debug!("Unmounting old root");
    if chdir(&PathBuf::from("/")).is_err() {
        return Err(Errcode::MountsError(5));
    }
    Ok(())
}
