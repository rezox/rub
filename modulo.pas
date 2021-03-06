unit modulo;
        (* this unit implements modulo arithmetic for RSA and ElGamal (cyclic group) *)

        (* this unit can easily be used to support other units which need limited 4096 cardinals (a.k.a. value)
        it has not been fully optimized, and the modulus must be set before performing operations. please note
        that negate results should be used with caution as the rounding process can take a while if certain size
        constraints are not met. this is why it has been commented out of the interface. it is suggested that
        the divide function is used rarely, but always before rescaling a number to another modulus. *)

interface
        const
                upper = 127;
        type
                (* i seem to have this as little endian cardinal ordering *)
                value = array [0 .. upper] of cardinal;
                pair = array [0 .. 1] of value;

        var
                iModulus: value; (* two's complement modulus *)
                modulus: value;
                zero: value;
                one: value;
                nogo: boolean;

        (* i do find the need to match the names of parameters more of a problem than matching types
        between the forward definition and implementation *)

        (* arithmetic functions *)
        function add(a: value; b: value): value;
        function mul(a: value; b: value): value;
        function setModulus(a: value): value; (* old *)
        (* function negate(a: value): value; (* not a modulo negate, but for subtraction *) *)
        function sub(a: value; b: value): value;

        (* more advanced functions *)
        function divide(a: value; b: value): pair; (* 0 = quotient, 1 = remainder *)
        function power(a: value; b: value): value;
        function gcd(a: value; b: value): value;
        function inverse(a: value): value;
        function greater(a: value; b: value): boolean; (* or equal to *)
        function equal(a: value; b: value): boolean;

implementation
        type
                fType = function (a, b: value): value;

        function addt(a: value; b: value; d: boolean): value;
        var
                i: integer;
                c: cardinal;
                q: qword;
        begin
                c := 0;
                for i := 0 to upper do
                begin
                        q := a[i] + b[i] + c;
                        c := q >> 32;
                        addt[i] := q and not 0;
                end;
                if d and (c <> 0) then addt := addt(addt, iModulus, false); (* horrid nest fix *)
        end;

        function greater(a: value; b: value): boolean;
        var
                i: integer;
        begin
                for i := upper downto 0 do
                begin
                        if a[i] < b[i] then
                        begin
                                greater := false;
                                exit;
                        end;
                        if a[i] > b[i] then
                        begin
                                greater := true;
                                exit;
                        end;
                end;
                greater := true; (* should make 0 *)
        end;

        function equal(a: value; b: value): boolean;
        begin
                equal := greater(a, b) and greater(b, a);
        end;

        function round(a: value): value;
        begin
                round := a;
                if greater(modulus, one) then (* zero is no modulus *)
                        while greater(round, modulus) do
                                a := addt(round, iModulus, false);
        end;

        function add(a: value; b: value): value;
        begin
                add := addt(a, b, true);
                add := round(add);
        end;

        function negate(a: value): value;
        var
                i: integer;
        begin
                for i := 0 to upper do
                        a[i] := not a[i];
                addt(a, one, false);
        end;

        function setModulus(a: value): value;
        var
                i: integer;
        begin
                setModulus := modulus; (* save it *)
                for i := 0 to upper do
                        zero[i] := 0;
                one := zero;
                one[0] := 1;
                modulus := a;
                iModulus := negate(a);
        end;

        function sub(a: value; b: value): value;
        begin
                sub := addt(a, negate(b), false);
                nogo := false;
                if greater(b, a) then
                begin
                        (* remap the negative *)
                        sub := addt(sub, modulus, false);
                        nogo := true;
                end;
        end;

        function mult(a: value; b: value; q: fType; e: value): value;
        var
                i: integer;
                f: boolean;
        begin
                mult := e;
                for i := 0 to (upper+1)*32-1 do
                begin
                        if (b[i div 32] and (1 << (i mod 32))) <> 0 then f := true else f := false;
                        if f then mult := q(mult, a);
                        a := q(a, a); (* effective shift under modulo field *)
                end;
        end;

        function mul(a: value; b: value): value;
        begin
                (* mult(a, b, @add(x, y), could_be_x_or_y_and_not_here); (* as what is c and d *) *)
                mult(a, b, @add, zero);
        end;

        function power(a: value; b: value): value;
        begin
                mult(a, b, @mul, one);
        end;

        function divide(a: value; b: value): pair;
        var
                i: integer;
                f: boolean;
                r, tmp: value;
        begin
                r := zero;
                tmp := setModulus(zero);
                for i := 0 to (upper+1)*32-1 do
                begin
                        r := addt(r, r, false);
                        if (a[upper] and (1 << 31)) <> 0 then
                                r := addt(r, one, false);
                        a := addt(a, a, false); (* shift *)
                        r := sub(r, b);
                        if nogo then
                                r := addt(r, b, false) (* add back *)
                        else
                                a := addt(a, one, false); (* divides *)
                end;
                divide[0] := a;
                divide[1] := r;
                tmp := setModulus(tmp);
        end;

        function gcdt(a: value; b: value; c: boolean): value;
        var
                t, newt, q, temp: value;
                p: pair;
                s: boolean = false; (* positive *)
                news: boolean = false;
        begin
                t := zero;
                newt := one;
                temp := setModulus(zero);
                if greater(b, a) then
                begin
                        gcdt := a;
                        a := b;
                        b := gcdt; (* swap *)
                end;
                while not equal(b, zero) do
                begin
                        p := divide(a, b);
                        q := p[0];
                        gcdt := p[1];
                        a := b;
                        b := gcdt;
                        if c then
                        begin
                                gcdt := newt;
                                if news then
                                begin
                                        newt := negate(newt);
                                        t := negate(t);
                                end;
                                s := news;
                                newt := sub(t, mul(q, newt));
                                news := nogo;
                                if s then
                                begin
                                        newt := negate(newt);
                                        news := not news;
                                end;
                                t := gcdt;
                        end;
                end;
                if not c then gcdt := a;
                (* inv or not *)
                if c then gcdt := t;
                if s then gcdt := addt(negate(gcdt), temp, false); (* sign magnitude to twos complement *)
                if (greater(sub(a, one), one) and c) then gcdt := zero; (* no inverse *)
                temp := setModulus(temp);
        end;

        function gcd(a: value; b: value): value;
        begin
                gcdt(a, b, false);
        end;

        function inverse(a: value): value;
        begin
                gcdt(a, modulus, true);
        end;

begin

end.
