cmake_minimum_required(VERSION 3.18.1)

project("agdk_eframe")

# Добавляем JNI wrapper для gstd
add_library(gstd_jni SHARED gstd_wrapper.c)

# Линкуем с Android log
find_library(log-lib log)
target_link_libraries(gstd_jni ${log-lib})

# Линкуем с libgstd.so (она будет загружена динамически)
# Указываем, что gstd_start и gstd_stop будут доступны во время выполнения
target_link_libraries(gstd_jni -Wl,--no-undefined)

# Основная библиотека вашего приложения (если есть)
# add_library(main SHARED main.cpp)
# target_link_libraries(main ${log-lib})