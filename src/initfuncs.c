/*
 * Copyright (C) 2023-24 Hamish Coleman
 * SPDX-License-Identifier: GPL-3.0-only
 *
 * Wrapper to call initfuncs
 */

// prototype any internal (non-public) initfuncs
void n3n_initfuncs_conffile_defs ();
void n3n_initfuncs_transform ();

void n3n_initfuncs () {
    // TODO:
    // - ideally, these functions would all be defined statically as
    //   constructors within their own object file, but we need to reference
    //   them externally or the linker will never link that object

    n3n_initfuncs_conffile_defs();
    n3n_initfuncs_transform();
}
