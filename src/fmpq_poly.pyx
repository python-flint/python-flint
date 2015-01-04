cdef any_as_fmpq_poly(obj):
    if typecheck(obj, fmpq_poly):
        return obj
    x = any_as_fmpz(obj)
    if x is not NotImplemented:
        r = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_set_fmpz((<fmpq_poly>r).val, (<fmpz>x).val)
        return r
    x = any_as_fmpz_poly(obj)
    if x is not NotImplemented:
        r = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_set_fmpz_poly((<fmpq_poly>r).val, (<fmpz_poly>x).val)
        return r
    x = any_as_fmpq(obj)
    if x is not NotImplemented:
        r = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_set_fmpq((<fmpq_poly>r).val, (<fmpq>x).val)
        return r
    return NotImplemented

cdef fmpq_poly_set_list(fmpq_poly_t poly, list val):
    cdef long i, n
    n = PyList_GET_SIZE(<PyObject*>val)
    fmpq_poly_fit_length(poly, n)
    for i from 0 <= i < n:
        c = val[i]
        x = any_as_fmpz(c)
        if x is not NotImplemented:
            fmpq_poly_set_coeff_fmpz(poly, i, (<fmpz>x).val)
            continue
        x = any_as_fmpq(c)
        if x is not NotImplemented:
            fmpq_poly_set_coeff_fmpq(poly, i, (<fmpq>x).val)
            continue
        raise TypeError("unsupported coefficient in list")

cdef class fmpq_poly(flint_poly):
    """
    The fmpq_poly type represents dense univariate polynomials
    over the rational numbers. For efficiency reasons, an fmpq_poly is
    structurally an integer polynomial with a single common denominator.

        >>> fmpq_poly([1,2,3],5) ** 3
        fmpq_poly([1, 6, 21, 44, 63, 54, 27], 125)
        >>> print _
        27/125*x^6 + 54/125*x^5 + 63/125*x^4 + 44/125*x^3 + 21/125*x^2 + 6/125*x + 1/125
        >>> divmod(fmpq_poly([2,0,1,1,6]), fmpq_poly([3,5,7]))
        (fmpq_poly([38, -161, 294], 343), fmpq_poly([572, 293], 343))

    """

    cdef fmpq_poly_t val

    def __cinit__(self):
        fmpq_poly_init(self.val)

    def __dealloc__(self):
        fmpq_poly_clear(self.val)

    def __init__(self, p=None, q=None):
        if p is not None:
            if typecheck(p, fmpq_poly):
                fmpq_poly_set(self.val, (<fmpq_poly>p).val)
            elif typecheck(p, fmpz_poly):
                fmpq_poly_set_fmpz_poly(self.val, (<fmpz_poly>p).val)
            elif isinstance(p, list):
                fmpq_poly_set_list(self.val, p)
            else:
                raise TypeError("cannot create fmpq_poly from input of type %s", type(p))
        if q is not None:
            q = any_as_fmpz(q)
            if q is NotImplemented:
                raise TypeError("denominator must be an integer, got %s", type(q))
            if fmpz_is_zero((<fmpz>q).val):
                raise ZeroDivisionError("cannot create fmpq_poly with zero denominator")
            fmpq_poly_scalar_div_fmpz(self.val, self.val, (<fmpz>q).val)

    def __len__(self):
        return fmpq_poly_length(self.val)

    cpdef long length(self):
        return fmpq_poly_length(self.val)

    cpdef long degree(self):
        return fmpq_poly_degree(self.val)

    def __richcmp__(self, other, int op):
        cdef bint r
        if op != 2 and op != 3:
            raise TypeError("polynomials cannot be ordered")
        self = any_as_fmpq_poly(self)
        if self is NotImplemented:
            return self
        other = any_as_fmpq_poly(other)
        if other is NotImplemented:
            return other
        r = fmpq_poly_equal((<fmpq_poly>self).val, (<fmpq_poly>other).val)
        if op == 3:
            r = not r
        return r

    def numer(self):
        cdef fmpz_poly x = fmpz_poly.__new__(fmpz_poly)
        fmpq_poly_get_numerator(x.val, self.val)
        return x

    def denom(self):
        cdef fmpz x = fmpz.__new__(fmpz)
        fmpz_set(x.val, fmpq_poly_denref(self.val))
        return x

    p = property(numer)
    q = property(denom)

    def __iter__(self):
        cdef long i, n
        n = self.length()
        for i from 0 <= i < n:
            yield self[i]

    def coeffs(self):
        cdef long i, n
        cdef list L
        n = self.length()
        L = [fmpq() for i in range(n)]
        for i from 0 <= i < n:
            fmpq_poly_get_coeff_fmpq((<fmpq>(L[i])).val, self.val, i)
        return L

    def __getitem__(self, long i):
        cdef fmpq x
        x = fmpq()
        if i < 0:
            return x
        fmpq_poly_get_coeff_fmpq(x.val, self.val, i)
        return x

    def __setitem__(self, long i, x):
        if i < 0:
            raise ValueError("cannot assign to index < 0 of polynomial")
        v = fmpq(x)  # XXX
        fmpq_poly_set_coeff_fmpq(self.val, i, (<fmpq>v).val)

    def repr(self):
        d = self.denom()
        n = self.numer()
        if d == 1:
            return "fmpq_poly(%s)" % map(int, n.coeffs())
        else:
            return "fmpq_poly(%s, %s)" % (map(int, n.coeffs()), d)

    def str(self):
        cdef char * s = fmpq_poly_get_str_pretty(self.val, "x")
        try:
            res = str(s)
        finally:
            libc.stdlib.free(s)
        return res

    def __nonzero__(self):
        return not fmpq_poly_is_zero(self.val)

    def __call__(self, other):
        t = any_as_fmpz(other)
        if t is not NotImplemented:
            v = fmpq.__new__(fmpq)
            fmpq_poly_evaluate_fmpz((<fmpq>v).val, self.val, (<fmpz>t).val)
            return v
        t = any_as_fmpq(other)
        if t is not NotImplemented:
            v = fmpq.__new__(fmpq)
            fmpq_poly_evaluate_fmpq((<fmpq>v).val, self.val, (<fmpq>t).val)
            return v
        t = any_as_fmpq_poly(other)
        if t is not NotImplemented:
            v = fmpq_poly.__new__(fmpq_poly)
            fmpq_poly_compose((<fmpq_poly>v).val, self.val, (<fmpq_poly>t).val)
            return v
        raise TypeError("cannot call fmpq_poly with input of type %s", type(other))

    def __pos__(self):
        return self

    def __neg__(self):
        cdef fmpq_poly res = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_neg(res.val, self.val)
        return res

    def __add__(s, t):
        cdef fmpq_poly r
        s = any_as_fmpq_poly(s)
        if s is NotImplemented:
            return s
        t = any_as_fmpq_poly(t)
        if t is NotImplemented:
            return t
        r = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_add(r.val, (<fmpq_poly>s).val, (<fmpq_poly>t).val)
        return r

    def __sub__(s, t):
        cdef fmpq_poly r
        s = any_as_fmpq_poly(s)
        if s is NotImplemented:
            return s
        t = any_as_fmpq_poly(t)
        if t is NotImplemented:
            return t
        r = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_sub(r.val, (<fmpq_poly>s).val, (<fmpq_poly>t).val)
        return r

    def __mul__(s, t):
        cdef fmpq_poly r
        s = any_as_fmpq_poly(s)
        if s is NotImplemented:
            return s
        t = any_as_fmpq_poly(t)
        if t is NotImplemented:
            return t
        r = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_mul(r.val, (<fmpq_poly>s).val, (<fmpq_poly>t).val)
        return r

    def __floordiv__(s, t):
        cdef fmpq_poly r
        s = any_as_fmpq_poly(s)
        if s is NotImplemented:
            return s
        t = any_as_fmpq_poly(t)
        if t is NotImplemented:
            return t
        if fmpq_poly_is_zero((<fmpq_poly>t).val):
            raise ZeroDivisionError("fmpq_poly division by 0")
        r = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_div(r.val, (<fmpq_poly>s).val, (<fmpq_poly>t).val)
        return r

    def __mod__(s, t):
        cdef fmpq_poly r
        s = any_as_fmpq_poly(s)
        if s is NotImplemented:
            return s
        t = any_as_fmpq_poly(t)
        if t is NotImplemented:
            return t
        if fmpq_poly_is_zero((<fmpq_poly>t).val):
            raise ZeroDivisionError("fmpq_poly division by 0")
        r = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_rem(r.val, (<fmpq_poly>s).val, (<fmpq_poly>t).val)
        return r

    def __div__(fmpq_poly s, t):
        cdef fmpq_poly r
        t = any_as_fmpq(t)
        if t is NotImplemented:
            return t
        if fmpq_is_zero((<fmpq>t).val):
            raise ZeroDivisionError("fmpq_poly scalar division by 0")
        r = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_scalar_div_fmpq(r.val, (<fmpq_poly>s).val, (<fmpq>t).val)
        return r

    # __truediv__ = __div__ doesn't seem to work?
    def __truediv__(fmpq_poly s, t):
        return fmpq_poly.__div__(s, t)

    def __divmod__(s, t):
        cdef fmpq_poly P, Q
        s = any_as_fmpq_poly(s)
        if s is NotImplemented:
            return s
        t = any_as_fmpq_poly(t)
        if t is NotImplemented:
            return t
        if fmpq_poly_is_zero((<fmpq_poly>t).val):
            raise ZeroDivisionError("fmpq_poly divmod by 0")
        P = fmpq_poly.__new__(fmpq_poly)
        Q = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_divrem(P.val, Q.val, (<fmpq_poly>s).val, (<fmpq_poly>t).val)
        return P, Q

    def __pow__(fmpq_poly self, ulong exp, mod):
        cdef fmpq_poly res
        if mod is not None:
            raise NotImplementedError("fmpz_poly modular exponentiation")
        res = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_pow(res.val, self.val, exp)
        return res

    def gcd(self, other):
        """
        Returns the greatest common divisor of self and other.

            >>> A = fmpq_poly([1,2,6],6); B = fmpq_poly([4,2,1],12)
            >>> (A * B).gcd(B)
            fmpq_poly([4, 2, 1])

        """
        cdef fmpq_poly res
        other = any_as_fmpq_poly(other)
        if other is NotImplemented:
            raise TypeError("cannot convert input to fmpq_poly")
        res = fmpq_poly.__new__(fmpq_poly)
        fmpq_poly_gcd(res.val, self.val, (<fmpq_poly>other).val)
        return res

    def factor(self):
        """
        Factors self into irreducible polynomials. Returns (c, factors)
        where c is the leading coefficient and factors is a list of
        (poly, exp) pairs with all poly monic.

            >>> legendre_polynomial(5).factor()
            (fmpq(63,8), [(fmpq_poly([0, 1]), 1), (fmpq_poly([15, 0, -70, 0, 63], 63), 1)])
            >>> (fmpq_poly([1,-1],10) ** 5 * fmpq_poly([1,2,3],7)).factor()
            (fmpq(-3,700000), [(fmpq_poly([1, 2, 3], 3), 1), (fmpq_poly([-1, 1]), 5)])

        """
        c, fac = self.numer().factor()
        c = fmpq(c)
        for i in range(len(fac)):
            base, exp = fac[i]
            lead = base[base.degree()]
            base = fmpq_poly(base, lead)
            c *= lead ** exp
            fac[i] = (base, exp)
        return c / self.denom(), fac
