use crate::errors::Errcode;

use structopt::StructOpt;

#[derive(Debug, StructOpt)]
#[structopt(name = "crabcan", about = "A simple container in Rust.")]
pub struct Args {
    /// Activate debug mode
    // short and long flags (-d, --debug) will be deduced from the field's name
    #[structopt(short, long)]
    debug: bool,

    /// Configuration file for the container
    #[structopt(short, long)]
    pub config_file: std::path::PathBuf,

    /// Script to execute inside the container
    #[structopt(short, long)]
    pub script: std::path::PathBuf,

    /// ID of the user to change
    #[structopt(short, long)]
    pub uid: u32,

    /// ID of the group to change
    #[structopt(short, long)]
    pub gid: u32,
}

pub fn parse_args() -> Result<Args, Errcode> {
    let args = Args::from_args();

    if args.debug {
        setup_log(log::LevelFilter::Debug);
    } else {
        setup_log(log::LevelFilter::Info);
    }

    Ok(args)
}

pub fn setup_log(level: log::LevelFilter) {
    env_logger::Builder::from_default_env()
        .format_timestamp_secs()
        .filter(None, level)
        .init();
}
