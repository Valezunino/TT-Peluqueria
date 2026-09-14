"use client";
import {useEffect,useState} from "react";
import Link from "next/link";
import {db} from "@/lib/db";
import Panel from "@/components/Panel";
export default function Admin(){
 const [ready,setReady]=useState(false),[admin,setAdmin]=useState(false),[error,setError]=useState(""),[busy,setBusy]=useState(false);
 useEffect(()=>{if(!db){setReady(true);return;}let alive=true;const check=async()=>{const {data,error}=await db!.rpc("is_admin");if(alive){setAdmin(!error&&data===true);setReady(true);}};void check();const {data}=db.auth.onAuthStateChange(()=>{setTimeout(()=>void check(),0);});return()=>{alive=false;data.subscription.unsubscribe();};},[]);
 async function login(e:React.FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setError("");const form=new FormData(e.currentTarget);try{const result=await db!.auth.signInWithPassword({email:String(form.get("email")),password:String(form.get("password"))});if(result.error)throw result.error;const r=await db!.rpc("is_admin");if(!r.data)throw new Error("Esta cuenta no tiene acceso de administrador.");setAdmin(true);}catch(e){setError(e instanceof Error?e.message:"No pudimos ingresar.");}finally{setBusy(false);}}
 if(!ready)return <main className="login"><p>Comprobando acceso…</p></main>;
 if(admin)return <Panel/>;
 return <main className="login"><Link className="monogram" href="/">TT</Link><div className="card"><p className="eyebrow">TT PELUQUERÍA</p><h1>Tu negocio,<br/>en un solo lugar.</h1><p className="muted">Ingresá para administrar la agenda y la caja.</p>{!db?<p className="alert">Falta conectar Supabase. Seguí las instrucciones del archivo DEPLOYMENT.md del repositorio.</p>:<form onSubmit={login}><label>Correo electrónico<input name="email" type="email" required autoComplete="username"/></label><label>Contraseña<input name="password" type="password" required autoComplete="current-password"/></label><button className="wide" disabled={busy}>{busy?"Ingresando…":"Ingresar"}</button></form>}{error&&<p role="alert" className="alert">{error}</p>}<Link className="contact" href="/">Volver a la página pública</Link></div></main>;
}