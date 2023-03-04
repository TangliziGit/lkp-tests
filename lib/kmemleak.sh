#!/bin/bash

kmemleak_is_enabled()
{
       [ -f /sys/kernel/debug/kmemleak ]
}
