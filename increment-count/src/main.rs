use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use sqlx::postgres::PgPool;
use anyhow::Result;
use serde::Serialize;

#[derive(Serialize)]
struct DBResp {
    count: i32,
    ip_addr: String,
}

struct AppState {
    pool: PgPool,
    ip_addr: String,
}

async fn increment(data: web::Data<AppState>) -> impl Responder {
    match sqlx::query!("UPDATE counter SET requests = requests + 1")
        .execute(&data.pool)
        .await
    {
        Ok(_) => HttpResponse::Ok().body("Success!"),
        Err(e) => {
            eprintln!("Error incrementing count: {:?}", e);
            HttpResponse::InternalServerError().body("Failed to increment count")
        },
    }
}

async fn get_count(data: web::Data<AppState>) -> impl Responder {
    match sqlx::query!("SELECT requests FROM counter")
        .fetch_one(&data.pool)
        .await
    {
        Ok(rec) => {
            let db_resp = DBResp { count: rec.requests.unwrap_or(0), ip_addr: data.ip_addr.clone() };
            HttpResponse::Ok().json(db_resp)
        },
        Err(e) => {
            eprintln!("Error fetching count: {:?}", e);
            HttpResponse::InternalServerError().body("Failed to fetch count")
        },
    }
}

#[actix_web::main]
async fn main() -> Result<()> {
    let pool = PgPool::connect(&std::env::var("DATABASE_URL")?).await?;

    let cmd_output = std::process::Command::new("sh")
        .arg("-c")
        .arg("ip a")
        .output()
        .expect("failed to get IP address");

    let cmd_output_str = String::from_utf8(cmd_output.stdout)
        .expect("failed to parse output");

    let mut ip_addr: &str = "";
    for line in cmd_output_str.split("\n") {
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

    let app_state = web::Data::new(AppState {
        pool: pool,
        ip_addr: ip_addr.to_string(),
    });

    HttpServer::new(move || {
        App::new()
            .app_data(app_state.clone())
            .route("/", web::get().to(get_count))
            .route("/", web::post().to(increment))
    })
    .bind("0.0.0.0:8000")?
    .run()
    .await?;

    Ok(())
}