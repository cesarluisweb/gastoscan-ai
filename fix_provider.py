# -*- coding: utf-8 -*-
import re
with open("lib/providers/gasto_provider.dart", "r", encoding="utf-8", errors="ignore") as f:
    c = f.read()

c = re.sub(r'sesi.*n local', 'sesión local', c)
c = re.sub(r'ten.*a una cuenta\. Iniciar sesi.*n con ella\.', 'tenía una cuenta. Iniciar sesión con ella.', c)
c = re.sub(r'categor.*a \(b.*squeda insensible a may.*sculas\)', 'categoría (búsqueda insensible a mayúsculas)', c)
c = re.sub(r'categor.*a ha superado', 'categoría ha superado', c)
c = re.sub(r'una categor.*a', 'una categoría', c)

# auth logic fix for profile sync if needed, wait DeepCoder changed it to:
# final signedInUser = userCred.user;
# if (signedInUser != null) { ... }
# I'll just check if that's there, if not I'll add it.
if "final signedInUser = userCred.user;" not in c:
    c = c.replace("""            if (userCred.user != null) {
              await userCred.user!.updateProfile(displayName: googleUser.displayName, photoURL: googleUser.photoUrl);
              await userCred.user!.reload();
            }""", """            final signedInUser = userCred.user;
            if (signedInUser != null) {
              await signedInUser.updateProfile(displayName: googleUser.displayName, photoURL: googleUser.photoUrl);
              await signedInUser.reload();
            }""")

with open("lib/providers/gasto_provider.dart", "w", encoding="utf-8") as f:
    f.write(c)
