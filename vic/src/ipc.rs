use crate::errors::Errcode;

use std::os::unix::io::RawFd;
use nix::sys::socket::{socketpair, AddressFamily, SockType, SockFlag};

pub fn generate_socketpair() -> Result<(RawFd, RawFd), Errcode> {
    match socketpair(
        AddressFamily::Unix,
        SockType::SeqPacket,
        None,
        SockFlag::SOCK_CLOEXEC)
    {
        Ok(res) => Ok(res),
        Err(_) => Err(Errcode::SocketError(0))
    }
}
