use crate::capabilities::setcapabilities;
use crate::config::ContainerOpts;
use crate::errors::Errcode;
use crate::hostname::set_container_hostname;
use crate::mounts::setmountpoint;
use crate::syscalls::setsyscalls;

use nix::unistd::getgrouplist;
use nix::unistd::setgid;
use nix::unistd::setgroups;
use nix::unistd::setuid;
use nix::unistd::Gid;

use nix::sched::clone;
use nix::sched::CloneFlags;
use nix::sys::signal::Signal;
use nix::unistd::Uid;
use nix::unistd::{execve, Pid};
use std::ffi::CString;

const STACK_SIZE: usize = 1024 * 1024;
fn setup_container_configurations(config: &ContainerOpts) -> Result<(), Errcode> {
    set_container_hostname(&config.hostname)?;
    setmountpoint(config)?;
    setcapabilities()?;
    setsyscalls()?;
    setuser(config)?;
    Ok(())
}

fn setuser(config: &ContainerOpts) -> Result<(), Errcode> {
    let uid = config.uid_gid.0;
    let gid = config.uid_gid.1;

    let user = CString::new(config.username.as_str()).unwrap();
    match getgrouplist(user.as_c_str(), Gid::from_raw(gid)) {
        Ok(groups) => {
            if let Err(e) = setgroups(&groups) {
                log::error!("Error while changing the user groups: {e:?}");
                return Err(Errcode::ChildProcessError(1));
            }
        }
        Err(e) => {
            log::error!(
                "Unable to get group list for user {}: {e:?}",
                config.username
            );
            return Err(Errcode::ChildProcessError(2));
        }
    }
    if let Err(e) = setgid(Gid::from_raw(gid)) {
        log::error!("Error while changing the user group: {e:?}");
        return Err(Errcode::ChildProcessError(3));
    }

    if let Err(e) = setuid(Uid::from_raw(uid)) {
        log::error!("Error while changing the user ID: {e:?}");
        return Err(Errcode::ChildProcessError(4));
    }

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

    std::thread::sleep(std::time::Duration::from_millis(100));
    log::info!("Starting container with script {:?}", config.script,);

    let script: CString = CString::new(config.script.to_str().unwrap()).unwrap();
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
    flags.insert(CloneFlags::CLONE_NEWUTS);
    flags.insert(CloneFlags::CLONE_NEWCGROUP);
    flags.insert(CloneFlags::CLONE_NEWPID);
    flags.insert(CloneFlags::CLONE_NEWIPC);
    // flags.insert(CloneFlags::CLONE_NEWNET);

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
        }
    }
}
