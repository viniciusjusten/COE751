function Base.println(io1::IO, io2::IO, args...)
    println(io1, args...)
    println(io2, args...)
end
