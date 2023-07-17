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
    let path = PathBuf::from(format!("/tmp/vic/vic.{}", random_string(20)));
    std::fs::create_dir_all(path.parent().unwrap()).unwrap();
    if path.exists() {
        random_tmp_dir()
    } else {
        path
    }
}

pub fn remove_empty_dir_tree(src: &PathBuf) -> Result<(), Errcode> {
    match std::fs::read_dir(src) {
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
