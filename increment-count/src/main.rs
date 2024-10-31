use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use sqlx::postgres::PgPool;
use anyhow::Result;
use serde::Serialize;

#[derive(Serialize)]
struct DBResp {
    count: i32,
}

async fn increment(pool: web::Data<PgPool>) -> impl Responder {
    match sqlx::query!("UPDATE counter SET requests = requests + 1")
        .execute(pool.get_ref())
        .await
    {
        Ok(_) => HttpResponse::Ok().body("Success!"),
        Err(e) => {
            eprintln!("Error incrementing count: {:?}", e);
            HttpResponse::InternalServerError().body("Failed to increment count")
        },
    }
}

async fn get_count(pool: web::Data<PgPool>) -> impl Responder {
    match sqlx::query!("SELECT requests FROM counter")
        .fetch_one(pool.get_ref())
        .await
    {
        Ok(rec) => {
            let db_resp = DBResp { count: rec.requests.unwrap_or(0) };
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

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(pool.clone()))
            .route("/", web::get().to(get_count))
            .route("/", web::post().to(increment))
    })
    .bind("0.0.0.0:8000")?
    .run()
    .await?;

    Ok(())
}