use crate::errors::Errcode;

use capctl::caps::Cap;
use capctl::caps::FullCapState;

use lazy_static::lazy_static;

lazy_static! {
    /// This is an example for using doc comment attributes
    static ref CAPABILITIES_DROP : Vec<Cap> = Vec::from([
        // Cap::AUDIT_CONTROL,
        // Cap::AUDIT_READ,
        // Cap::AUDIT_WRITE,
        // Cap::BLOCK_SUSPEND,
        // Cap::DAC_READ_SEARCH,
        // Cap::DAC_OVERRIDE,
        // Cap::FSETID,
        // Cap::IPC_LOCK,
        // Cap::MAC_ADMIN,
        // Cap::MAC_OVERRIDE,
        // Cap::MKNOD,
        // Cap::SETFCAP,
        // Cap::SYSLOG,
        // Cap::SYS_ADMIN,
        // Cap::SYS_BOOT,
        // Cap::SYS_MODULE,
        // Cap::SYS_NICE,
        // Cap::SYS_RAWIO,
        // Cap::SYS_RESOURCE,
        // Cap::SYS_TIME,
        // Cap::WAKE_ALARM,
    ]);
}

pub fn setcapabilities() -> Result<(), Errcode> {
    log::debug!("Clearing unwanted capabilities ...");
    if let Ok(mut caps) = FullCapState::get_current() {
        caps.bounding.drop_all(CAPABILITIES_DROP.iter().copied());
        caps.inheritable.drop_all(CAPABILITIES_DROP.iter().copied());
        Ok(())
    } else {
        Err(Errcode::CapabilitiesError(0))
    }
}
