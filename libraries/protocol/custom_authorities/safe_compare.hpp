#ifndef BOOST_NUMERIC_SAFE_COMPARE_HPP
#define BOOST_NUMERIC_SAFE_COMPARE_HPP

// MS compatible compilers support #pragma once
#if defined(_MSC_VER) && (_MSC_VER >= 1020)
# pragma once
#endif

//  Copyright (c) 2012 Robert Ramey
//
// Distributed under the Boost Software License, Version 1.0. (See
// accompanying file BOOST_LICENSE_1_0.txt or copy at
// http://www.boost.org/LICENSE_1_0.txt)

#include <type_traits>
#include <limits>

namespace boost {
namespace safe_numerics {
namespace safe_compare {

// 1) some (broken, old MSVC?) compilers needed extra word "template" in some c++ expressions
// 2) other compilers do not need it, but allow it silently or with mild warning
// 3) others enforce correct C++ language, and the extra word will break compilation (new clang20 i.e.)
// the correct C++ is to define this macro to nothing "", so to not use the extra word "template" in this places
// here we enable the extra word if we think compiler needs it, or if it was done that way on that compilers before in this project
#if defined(_MSC_VER)
  // MSVC historically permissive — keep the token for compatibility
  #define EXP_TEMPLATE_DISAMBIG template
	// TODO one day on new MSVC we can also drop it
#elif defined(__clang__)
  // Treat Clang <= 19 (especially 18) as "old"
  #if __clang_major__ <= 19
    #define EXP_TEMPLATE_DISAMBIG template
  #else
    #define EXP_TEMPLATE_DISAMBIG
  #endif
#elif defined(__GNUC__)
  // Treat GCC <= 14 (especially 13) as "old"
  #if __GNUC__ <= 13
    #define EXP_TEMPLATE_DISAMBIG template
  #else
    #define EXP_TEMPLATE_DISAMBIG
  #endif
#else
  // for unknown compilers:
  #define EXP_TEMPLATE_DISAMBIG
#endif

////////////////////////////////////////////////////
// safe comparison on primitive integral types
namespace safe_compare_detail {
    template<typename T>
    using make_unsigned = typename std::conditional<
        std::is_signed<T>::value,
        std::make_unsigned<T>,
        T
    >::type;

    // both arguments unsigned or signed
    template<bool TS, bool US>
    struct less_than {
        template<class T, class U>
        constexpr static bool invoke(const T & t, const U & u){
            return t < u;
        }
    };

    // T unsigned, U signed
    template<>
    struct less_than<false, true> {
        template<class T, class U>
        constexpr static bool invoke(const T & t, const U & u){
            return
                (u < 0) ?
                    false
                :
                    less_than<false, false>::invoke(
                        t,
                        static_cast<const typename make_unsigned<U>::type &>(u)
                    )
                ;
        }
    };
    // T signed, U unsigned
    template<>
    struct less_than<true, false> {
        template<class T, class U>
        constexpr static bool invoke(const T & t, const U & u){
            return
                (t < 0) ?
                    true
                :
                    less_than<false, false>::invoke(
                        static_cast<const typename make_unsigned<T>::type &>(t),
                        u
                    )
                ;
        }
    };
} // safe_compare_detail

template<class T, class U>
typename std::enable_if<
    std::is_integral<T>::value && std::is_integral<U>::value,
    bool
>::type
constexpr less_than(const T & lhs, const U & rhs) {
    return safe_compare_detail::less_than<
        std::is_signed<T>::value,
        std::is_signed<U>::value
    >::EXP_TEMPLATE_DISAMBIG invoke(lhs, rhs);
}

template<class T, class U>
typename std::enable_if<
    std::is_floating_point<T>::value && std::is_floating_point<U>::value,
    bool
>::type
constexpr less_than(const T & lhs, const U & rhs) {
    return lhs < rhs;
}

template<class T, class U>
constexpr bool greater_than(const T & lhs, const U & rhs) {
    return less_than(rhs, lhs);
}

template<class T, class U>
constexpr bool less_than_equal(const T & lhs, const U & rhs) {
    return ! greater_than(lhs, rhs);
}

template<class T, class U>
constexpr bool greater_than_equal(const T & lhs, const U & rhs) {
    return ! less_than(lhs, rhs);
}

namespace safe_compare_detail {
    // both arguments unsigned or signed
    template<bool TS, bool US>
    struct equal {
        template<class T, class U>
        constexpr static bool invoke(const T & t, const U & u){
            return t == u;
        }
    };

    // T unsigned, U signed
    template<>
    struct equal<false, true> {
        template<class T, class U>
        constexpr static bool invoke(const T & t, const U & u){
            return
                (u < 0) ?
                    false
                :
                    equal<false, false>::invoke(
                        t,
                        static_cast<const typename make_unsigned<U>::type &>(u)
                    )
                ;
        }
    };
    // T signed, U unsigned
    template<>
    struct equal<true, false> {
        template<class T, class U>
        constexpr static bool invoke(const T & t, const U & u){
            return
                (t < 0) ?
                    false
                :
                    equal<false, false>::invoke(
                        static_cast<const typename make_unsigned<T>::type &>(t),
                        u
                    )
                ;
        }
    };
} // safe_compare_detail

template<class T, class U>
typename std::enable_if<
    std::is_integral<T>::value && std::is_integral<U>::value,
    bool
>::type
constexpr equal(const T & lhs, const U & rhs) {
    return safe_compare_detail::equal<
        std::numeric_limits<T>::is_signed,
        std::numeric_limits<U>::is_signed
    >::EXP_TEMPLATE_DISAMBIG invoke(lhs, rhs);
}

template<class T, class U>
typename std::enable_if<
    std::is_floating_point<T>::value && std::is_floating_point<U>::value,
    bool
>::type
constexpr equal(const T & lhs, const U & rhs) {
    return lhs == rhs;
}

template<class T, class U>
constexpr bool not_equal(const T & lhs, const U & rhs) {
    return ! equal(lhs, rhs);
}

} // safe_compare
} // safe_numerics
} // boost

#undef EXP_TEMPLATE_DISAMBIG

#endif // BOOST_NUMERIC_SAFE_COMPARE_HPP
