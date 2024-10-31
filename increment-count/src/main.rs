#![allow(unreachable_code)]
#[macro_use]
extern crate rouille;

fn main() {
    rouille::start_server("0.0.0.0:8000", move |request| {
        router!(request,
            (GET) (/) => {
                let output = std::process::Command::new("sh")
                    .arg("-c")
                    .arg("ip a")
                    .output()
                    .expect("failed to get IP address");

                let output_str = String::from_utf8(output.stdout)
                    .expect("failed to parse output");

                let mut ip_addr: &str = "";

                for line in output_str.split("\n") {
                    if line.contains("global eth0") {
                        for word in line.split(" ") {
                            if word.contains("/16") {
                                ip_addr = word.split("/").collect::<Vec<&str>>()[0];
                                break;
                            }
                        }
                        break;
                    }
                }

                if ip_addr.is_empty() {
                    ip_addr = "no ip address found";
                }

                rouille::Response::text(ip_addr)
            },
            _ => rouille::Response::empty_404()
        )
    });
}