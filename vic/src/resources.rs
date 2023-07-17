use crate::errors::Errcode;

use cgroups_rs::cgroup_builder::CgroupBuilder;
use cgroups_rs::hierarchies::V2;
use cgroups_rs::{CgroupPid, MaxValue};
use nix::unistd::Pid;
use rlimit::{setrlimit, Resource};

use std::convert::TryInto;
use std::fs::{canonicalize, remove_dir};

// TODO    Set from configuration
const CPU_SHARES: u64 = 256;
//                      K       M       G
const KMEM_LIMIT: i64 = 1024 * 1024 * 1024;
const MEM_LIMIT: i64 = KMEM_LIMIT;
const MAX_PID: MaxValue = MaxValue::Value(1024);
const NOFILE_RLIMIT: u64 = 256;

pub fn restrict_resources(hostname: &String, pid: Pid) -> Result<(), Errcode> {
    log::debug!("Restricting resources for hostname {}", hostname);

    let cgs = CgroupBuilder::new(hostname)
        .cpu()
        .shares(CPU_SHARES)
        .done()
        .memory()
        .kernel_memory_limit(KMEM_LIMIT)
        .memory_hard_limit(MEM_LIMIT)
        .done()
        .pid()
        .maximum_number_of_processes(MAX_PID)
        .done()
        .blkio()
        .weight(50)
        .done()
        .build(Box::new(V2::new()));

    let pid: u64 = pid.as_raw().try_into().unwrap();
    if let Err(e) = cgs.add_task(CgroupPid::from(pid)) {
        log::error!("Error while adding task to Cgroup: {e:?}");
        return Err(Errcode::ResourcesError(0));
    };

    if let Err(e) = setrlimit(Resource::NOFILE, NOFILE_RLIMIT, NOFILE_RLIMIT) {
        log::error!("Error while setting rlimit: {e:?}");
        return Err(Errcode::ResourcesError(1));
    }

    Ok(())
}

pub fn clean_cgroups(hostname: &String) -> Result<(), Errcode> {
    match canonicalize(format!("/sys/fs/cgroup/{}/", hostname)) {
        Ok(d) => {
            if let Err(e) = remove_dir(&d) {
                log::error!("Error when removing {d:?}: {e:?}");
                return Err(Errcode::ResourcesError(2));
            }
        }
        Err(e) => {
            log::error!("Error while canonicalize path: {}", e);
            return Err(Errcode::ResourcesError(3));
        }
    }
    Ok(())
}
