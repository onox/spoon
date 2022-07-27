// SPDX-License-Identifier: Apache-2.0
//
// Copyright (c) 2022 onox <denkpadje@gmail.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <spawn.h>
#include <fcntl.h>
#include <sys/wait.h>

const size_t spoon_posix_spawn_file_actions_t_size = sizeof(posix_spawn_file_actions_t);
const size_t spoon_posix_spawnattr_t_size = sizeof(posix_spawnattr_t);
const size_t spoon_sigset_t_size = sizeof(sigset_t);

const int spoon_o_cloexec = O_CLOEXEC;

int spoon_waitpid_status (int wstatus, int *status) {
    if (WIFEXITED(wstatus)) {
        *status = WEXITSTATUS(wstatus);
        return 0;
    }
    else if (WIFSIGNALED(wstatus)) {
        *status = WTERMSIG(wstatus);

        // Signals whose default disposition is "Core" in the list of standard
        // signals in the man page of signal(7).
        switch (*status) {
            case SIGABRT:
            case SIGBUS:
            case SIGFPE:
            case SIGILL:
            case SIGQUIT:
            case SIGSEGV:
            case SIGSYS:
            case SIGTRAP:
            case SIGXCPU:
            case SIGXFSZ:
                return 1;
            default:
                return 2;
        }
    }
    return -1;
}
