project(pg)
cmake_minimum_required(VERSION 3.10)

include(cmake/pkg.cmake)

file(GLOB_RECURSE resources scripts/*.lua)
create_resource(${CMAKE_CURRENT_SOURCE_DIR} "${resources}" pg COPY)