package com.vdzon.newsfeedbackend.model

data class CategoryResult(
    val categoryId: String,
    val categoryName: String,
    val articleCount: Int,
    val costUsd: Double
)
