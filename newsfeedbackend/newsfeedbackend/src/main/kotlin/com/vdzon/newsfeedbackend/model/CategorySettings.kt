package com.vdzon.newsfeedbackend.model

data class CategorySettings(
    val id: String,
    val name: String,
    val enabled: Boolean = true,
    val extraInstructions: String = "",
    val isSystem: Boolean = false,
    val preferredCount: Int = 3,
    val maxCount: Int = 5
)
