import test from "node:test";
import assert from "node:assert/strict";
import {dayKey,shift,summarize} from "../src/lib/model.ts";
import type {Payment} from "../src/lib/model.ts";
test("Midnight boundaries use Argentina time",()=>{assert.equal(dayKey("2026-09-15T02:59:00Z"),"2026-09-14");assert.equal(dayKey("2026-09-15T03:00:00Z"),"2026-09-15");});
test("Calendar handles month and leap-year transitions",()=>{assert.equal(shift("2026-03-01",-1),"2026-02-28");assert.equal(shift("2024-03-01",-1),"2024-02-29");});
test("Cash totals use actual payment timestamps and unique customers",()=>{const rows=[{id:"1",appointment_id:"a",customer_id:"c",paid_at:"2026-09-15T02:00:00Z",amount:15000,method:"Efectivo",customer_name:"Juan"},{id:"2",appointment_id:"b",customer_id:"c",paid_at:"2026-09-15T03:01:00Z",amount:17000,method:"Tarjeta",customer_name:"Juan"}] as Payment[];assert.equal(summarize(rows,"2026-09-14","2026-09-14").total,15000);assert.equal(summarize(rows,"2026-09-14","2026-09-15").customers,1);assert.equal(summarize(rows,"2026-09-14","2026-09-15").cuts,2);});
