--  SPDX-License-Identifier: Apache-2.0
--
--  Copyright (c) 2022 onox <denkpadje@gmail.com>
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.

with Ada.Unchecked_Conversion;

package body Spoon.Output is

   protected body Text_Capturer is
      procedure Write
        (Value : Ada.Streams.Stream_Element_Array;
         Kind  : Output_Kind)
      is
         subtype Source_Type is Ada.Streams.Stream_Element_Array (1 .. Value'Length);
         subtype Target_Type is String (1 .. Value'Length);

         function Convert is new Ada.Unchecked_Conversion
           (Source => Source_Type, Target => Target_Type);
      begin
         SU.Append (Text (Kind), Convert (Value));
      end Write;

      function Get (Kind : Output_Kind) return SU.Unbounded_String is (Text (Kind));
   end Text_Capturer;

end Spoon.Output;
