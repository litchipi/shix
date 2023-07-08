use crate::capabilities::setcapabilities;
use crate::config::ContainerOpts;
use crate::errors::Errcode;
use crate::hostname::set_container_hostname;
use crate::mounts::setmountpoint;
use crate::syscalls::setsyscalls;

use nix::sched::clone;
use nix::sched::CloneFlags;
use nix::sys::signal::Signal;
use nix::unistd::{execve, Pid};
use std::ffi::CString;

const STACK_SIZE: usize = 1024 * 1024;
fn setup_container_configurations(config: &ContainerOpts) -> Result<(), Errcode> {
    set_container_hostname(&config.hostname)?;
    setmountpoint(
        &config.new_root,
        &config.root_mount_point,
        &config.home_dir,
        &config.addpaths
    )?;
    setcapabilities()?;
    setsyscalls()?;
    Ok(())
}

fn child(config: ContainerOpts) -> isize {
    match setup_container_configurations(&config) {
        Ok(_) => log::info!("Container set up successfully"),
        Err(e) => {
            log::error!("Error while configuring container: {:?}", e);
            return -1;
        }
    }

    log::info!(
        "Starting container with script {:?}", 
        config.script,
    );

    let script : CString = CString::new(config.script.to_str().unwrap()).unwrap();
    match execve::<CString, CString>(&script, &[script.clone()], &[]) {
        Ok(_) => 0,
        Err(e) => {
            log::error!("Error while trying to perform execve: {:?}", e);
            -1
        }
    }
}

pub fn generate_child_process(config: ContainerOpts) -> Result<Pid, Errcode> {
    let mut tmp_stack: [u8; STACK_SIZE] = [0; STACK_SIZE];
    let mut flags = CloneFlags::empty();
    flags.insert(CloneFlags::CLONE_NEWNS);
    flags.insert(CloneFlags::CLONE_NEWCGROUP);
    flags.insert(CloneFlags::CLONE_NEWPID);
    flags.insert(CloneFlags::CLONE_NEWIPC);
    flags.insert(CloneFlags::CLONE_NEWNET);
    flags.insert(CloneFlags::CLONE_NEWUTS);

    match clone(
        Box::new(|| child(config.clone())),
        &mut tmp_stack,
        flags,
        Some(Signal::SIGCHLD as i32),
    ) {
        Ok(pid) => Ok(pid),
        Err(e) => {
            log::error!("Error cloning the process: {e:?}");
            Err(Errcode::ChildProcessError(0))
        },
    }
}
