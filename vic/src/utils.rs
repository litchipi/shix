use std::path::PathBuf;

use rand::Rng;

use crate::errors::Errcode;
pub fn random_string(n: usize) -> String {
    const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ\
                            abcdefghijklmnopqrstuvwxyz\
                            0123456789";
    let mut rng = rand::thread_rng();

    let name: String = (0..n)
        .map(|_| {
            let idx = rng.gen_range(0..CHARSET.len());
            CHARSET[idx] as char
        })
        .collect();

    name
}

pub fn random_tmp_dir() -> PathBuf {
    let path = PathBuf::from(format!("/tmp/vic.{}", random_string(20)));
    if path.exists() {
        random_tmp_dir()
    } else {
        path
    }
}

pub fn remove_empty_dir_tree(src: &PathBuf) -> Result<(), Errcode> {
    match std::fs::read_dir(&src) {
        Err(e) => {
            log::error!("Error while listing files in {src:?}: {e:?}");
            Err(Errcode::UtilError(
                "remove_empty_dir_tree",
                format!("{src:?} not a directory"),
            ))
        }
        Ok(all_paths) => {
            for path in all_paths {
                let path = path.unwrap().path();
                if !path.is_dir() {
                    return Err(Errcode::UtilError(
                        "remove_empty_dir_tree",
                        format!("Directory {src:?} not empty"),
                    ));
                }
                remove_empty_dir_tree(&path)?;
            }
            if let Err(e) = std::fs::remove_dir(src) {
                log::error!("Unable to remove directory {src:?}: {e:?}");
            }
            Ok(())
        }
    }
}

use lazy_static::lazy_static;

lazy_static! {
    /// This is an example for using doc comment attributes
    static ref TMP_FILES_CLEAN : Vec<&'static str> = Vec::from([
        "/var/db/sudo/lectured"
    ]);
}

pub fn clean_tmp_files(root: &PathBuf) {
    for str_path in TMP_FILES_CLEAN.iter() {
        let path = if let Some(p) = str_path.strip_prefix("/") {
            root.join(p)
        } else {
            root.join(str_path)
        };

        if path.exists() {
            if let Err(e) = if path.is_dir() {
                std::fs::remove_dir_all(&path)
            } else {
                std::fs::remove_file(&path)
            } {
                log::warn!("Unable to clean tmp file {path:?}: {e:?}");
            }
        } else {
            log::warn!("Unable to clean tmp file {path:?}: not found");
        }
    }
}
