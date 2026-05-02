package com.vdzon.newsfeedbackend.model

data class User(
    val id: String,
    val username: String,
    val passwordHash: String
)
