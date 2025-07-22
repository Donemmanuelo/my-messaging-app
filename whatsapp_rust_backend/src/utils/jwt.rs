use crate::models::Claims;
use anyhow::Result;
use chrono::{Duration, Utc};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use std::env;

pub fn create_jwt(user_id: &str) -> Result<String> {
    let exp = Utc::now().checked_add_signed(Duration::hours(72)).expect("Failed to create expiration").timestamp();
    let claims = Claims { sub: user_id.to_owned(), exp: exp as usize };
    encode(&Header::default(), &claims, &EncodingKey::from_secret(env::var("JWT_SECRET").unwrap().as_ref())).map_err(Into::into)
}
pub fn decode_jwt(token: &str) -> Result<Claims> {
    decode::<Claims>(token, &DecodingKey::from_secret(env::var("JWT_SECRET").unwrap().as_ref()), &Validation::default()).map(|d| 
d.claims).map_err(Into::into)
}
