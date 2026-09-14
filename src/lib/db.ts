import { createClient } from "@supabase/supabase-js";
const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
const key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
export const db=url&&key?createClient(url,key):null;
export async function rpc<T>(name:string,args:Record<string,unknown>={}):Promise<T>{
 if(!db) throw new Error("La conexión todavía no está configurada.");
 const {data,error}=await db.rpc(name,args); if(error) throw new Error(error.message); return data as T;
}
export async function all<T>(table:string):Promise<T[]>{
 if(!db) throw new Error("Sin conexión");
 const rows:T[]=[]; for(let from=0;;from+=1000){const {data,error}=await db.from(table).select("*").order("id").range(from,from+999); if(error)throw error;rows.push(...data as T[]);if(data.length<1000)break;}return rows;
}
