package com.vdzon.newsfeedbackend.model

data class CategoryResult(
    val categoryId: String,
    val categoryName: String,
    val articleCount: Int,
    val costUsd: Double,
    val searchResultCount: Int = 0,   // aantal resultaten van Tavily
    val filteredCount: Int = 0        // aantal over na datum-filter
)
