use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use sqlx::postgres::PgPool;
use anyhow::Result;
use serde::Serialize;

#[derive(Serialize)]
struct PostResponse {
    language: String,
    ip_address: String,
    l_count: i32,
}

#[derive(Serialize)]
struct GetResponse {
    language: String,
    ip_address: String,
    total_l_count: i32,
}

struct WebData {
    pg_pool: PgPool,
    ip_address: String,
}

async fn increment(data: web::Data<WebData>, req_body: web::Bytes) -> impl Responder {
    let mut count_ls : i32 = 0;
    let body_str = match String::from_utf8(req_body.to_vec()) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Invalid UTF8: {:?}", e);
            return HttpResponse::BadRequest().body("Invalid binary string")
        }
    };

    for c in body_str.chars() {
        if c == 'l' || c == 'L' {
            count_ls += 1;
        }
    }

    match sqlx::query!("UPDATE l_count SET num_ls = num_ls + $1", count_ls)
        .execute(&data.pg_pool)
        .await
    {
        Ok(_) => {
            let resp = PostResponse {
                language: String::from("Rust"),
                ip_address: data.ip_address.clone(),
                l_count: count_ls,
            };

            fib(43);

            return HttpResponse::Ok().json(resp);
        }
        Err(e) => {
            eprintln!("Error incrementing count: {:?}", e);
            return HttpResponse::InternalServerError().body("Failed to increment count")
        },
    }
}

async fn get_count(data: web::Data<WebData>) -> impl Responder {
    match sqlx::query!("SELECT num_ls FROM l_count")
        .fetch_one(&data.pg_pool)
        .await
    {
        Ok(rec) => {
            let resp = GetResponse {
                total_l_count: rec.num_ls.unwrap_or(0),
                language: String::from("Rust"),
                ip_address: data.ip_address.clone(),
             };

            return HttpResponse::Ok().json(resp)
        },
        Err(e) => {
            eprintln!("Error fetching count: {:?}", e);
            return HttpResponse::InternalServerError().body("Failed to fetch count")
        },
    }
}

async fn reset_count(data: web::Data<WebData>) -> impl Responder {
    match sqlx::query!("UPDATE l_count SET num_ls = 0")
        .execute(&data.pg_pool)
        .await
    {
        Ok(_) => {
            let resp = GetResponse {
                total_l_count: 0,
                language: String::from("Rust"),
                ip_address: data.ip_address.clone(),
            };

            return HttpResponse::Ok().json(resp)
        },
        Err(e) => {
            eprintln!("Error resetting count: {:?}", e);
            return HttpResponse::InternalServerError().body("Failed to reset count")
        },
    }
}

#[actix_web::main]
async fn main() -> Result<()> {
    let database_url = std::env::var("DATABASE_URL").expect("Environment variable 'DATABASE_URL' not found");
    let ip_addr = std::env::var("POD_IP").expect("Environment variable 'POD_IP' not found");
    let pool = PgPool::connect(&database_url).await.expect("Failed to create pool");
    let data = web::Data::new(WebData {
        pg_pool: pool,
        ip_address: ip_addr,
    });


    HttpServer::new(move || {
        App::new()
            .app_data(data.clone())
            .route("/", web::get().to(get_count))
            .route("/", web::post().to(increment))
            .route("/", web::delete().to(reset_count))
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await?;

    Ok(())
}

fn fib(n: i8) -> i8 {
	if n < 2 {
		return n
	}
	return fib(n-2) + fib(n-1)
}
