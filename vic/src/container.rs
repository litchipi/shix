use crate::child::generate_child_process;
use crate::cli::Args;
use crate::config::ContainerOpts;
use crate::errors::Errcode;
use crate::resources::{clean_cgroups, restrict_resources};
use crate::utils::remove_empty_dir_tree;

use nix::sys::utsname::uname;
use nix::sys::wait::waitpid;
use nix::unistd::Pid;

pub struct Container {
    config: ContainerOpts,
}

impl Container {
    pub fn new(args: Args) -> Result<Container, Errcode> {
        let mut config = ContainerOpts::from_file(&args.config_file)?;
        config.prepare_and_validate(&args)?;
        Ok(Container { config })
    }

    pub fn create(&mut self) -> Result<Pid, Errcode> {
        let pid = generate_child_process(self.config.clone())?;
        restrict_resources(&self.config.hostname, pid)?;
        log::debug!("Creation finished");
        Ok(pid)
    }

    pub fn clean_exit(&mut self) -> Result<(), Errcode> {
        for path in self.config.addpaths.iter() {
            if let Err(e) = path.clean(&self.config.root_mount_point) {
                log::warn!(
                    "Cleaning add path {:?} failed: {e:?}, skipping...",
                    path.dst
                );
            }
        }

        if let Err(e) = remove_empty_dir_tree(&self.config.new_root) {
            log::warn!(
                "Unable to remove new root dir {:?} (error: {e:?}), skipping ...",
                self.config.new_root
            );
        }

        if let Err(e) = clean_cgroups(&self.config.hostname) {
            log::warn!("Cgroups cleaning failed: {}, skipping...", e);
        }

        Ok(())
    }
}

pub const MINIMAL_KERNEL_VERSION: f32 = 4.8;

pub fn check_linux_version() -> Result<(), Errcode> {
    let host = uname();
    log::debug!("Linux release: {}", host.release());

    if let Ok(version) = scan_fmt!(host.release(), "{f}.{}", f32) {
        if version < MINIMAL_KERNEL_VERSION {
            return Err(Errcode::NotSupported(0));
        }
    } else {
        return Err(Errcode::ContainerError(0));
    }

    if host.machine() != "x86_64" {
        return Err(Errcode::NotSupported(1));
    }

    Ok(())
}

pub fn start(args: Args) -> Result<(), Errcode> {
    check_linux_version()?;
    let mut container = Container::new(args)?;
    match container.create() {
        Err(e) => {
            log::error!("Error while creating container: {:?}", e);
            container.clean_exit()?;
            Err(e)
        }
        Ok(pid) => {
            log::debug!("Container child PID: {:?}", pid);
            wait_child(pid)?;
            log::debug!("Finished, cleaning & exit");
            container.clean_exit()
        }
    }
}

pub fn wait_child(child_pid: Pid) -> Result<(), Errcode> {
    log::debug!("Waiting for child (pid {}) to finish", child_pid);
    if let Err(e) = waitpid(child_pid, None) {
        log::error!("Error while waiting for pid to finish: {:?}", e);
        return Err(Errcode::ContainerError(1));
    }
    Ok(())
}
