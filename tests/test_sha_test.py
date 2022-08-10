# Copyright 2022 Sabana Technologies, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from pathlib import Path
import numpy as np
from sabana import Instance, Program

def create_program(file):
    in_len = 16
    out_len = 8
    dtype = np.int32
    start = np.ones([1], dtype)
    finish = np.array([14], dtype)
    a = np.fromfile(file, dtype=np.uint8)
    a_len = np.array([in_len], dtype=dtype)
    y_len = np.array([out_len], dtype=dtype)
    program = Program()
    program.mmio_alloc(name="c0", size=0x00010000, base_address=0xA0000000)
    program.buffer_alloc(name="a", size=a.nbytes, mmio_name="c0", mmio_offset=0x10)
    program.buffer_alloc(name="y", size=out_len*4, mmio_name="c0", mmio_offset=0x24)
    program.mmio_write(a_len, name="c0", offset=0x1C)
    program.mmio_write(y_len, name="c0", offset=0x30)
    program.mmio_write(start, name="c0", offset=0x0)
    program.mmio_wait(finish, name="c0", offset=0x0, timeout=3)
    program.buffer_read(name="y", offset=0, dtype=np.uint8, shape=(out_len*4,))
    program.mmio_dealloc(name="c0")
    program.buffer_dealloc(name="a")
    program.buffer_dealloc(name="y")
    return program

def test_main():
    file = Path(__file__).resolve().parent.joinpath("single_block.txt.padded")
    prog = create_program(file)
    image_file = Path(__file__).resolve().parent.parent.joinpath("sabana.json")
    inst = Instance(image_file=image_file, verbose=True)
    inst.up()
    responses = inst.execute(prog)
    inst.down()
    print(responses[0])


if __name__ == "__main__":
    test_main()
