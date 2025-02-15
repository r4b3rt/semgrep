open Common

(*****************************************************************************)
(* Prelude *)
(*****************************************************************************)
(* Call 'dot', 'gv', or 'open' to display a graph *)

(*****************************************************************************)
(* Dot generation *)
(*****************************************************************************)

let generate_ograph_generic g label fnode (buf : Format.formatter) =
  Format.fprintf buf "digraph misc {\n";
  Format.fprintf buf "size = \"10,10\";\n";
  (match label with
  | None -> ()
  | Some x -> Format.fprintf buf "label = \"%s\";\n" x);
  let nodes = g#nodes in
  nodes#iter (fun (k, node) ->
      let str, border_color, inner_color = fnode (k, node) in
      let color =
        match inner_color with
        | None -> (
            match border_color with
            | None -> ""
            | Some x -> spf ", style=\"setlinewidth(3)\", color = %s" x)
        | Some x -> (
            match border_color with
            | None -> spf ", style=\"setlinewidth(3),filled\", fillcolor = %s" x
            | Some x' ->
                spf
                  ", style=\"setlinewidth(3),filled\", fillcolor = %s, color = \
                   %s"
                  x x')
      in
      (* so can see if nodes without arcs were created *)
      Format.fprintf buf "%d [label=\"%s   [%d]\"%s];\n" k str k color);

  nodes#iter (fun (k, _node) ->
      let succ = g#successors k in
      succ#iter (fun (j, _edge) -> Format.fprintf buf "%d -> %d;\n" k j));
  Format.fprintf buf "}\n"

let generate_ograph_xxx g filename =
  UFile.Legacy.with_open_outfile filename (fun (xpr, _) ->
      xpr "digraph misc {\n";
      xpr "size = \"10,10\";\n";

      let nodes = g#nodes in
      nodes#iter (fun (k, (_node, s)) ->
          (* so can see if nodes without arcs were created *)
          xpr (spf "%d [label=\"%s   [%d]\"];\n" k s k));

      nodes#iter (fun (k, _node) ->
          let succ = g#successors k in
          succ#iter (fun (j, _edge) -> xpr (spf "%d -> %d;\n" k j)));
      xpr "}\n");
  ()

(*****************************************************************************)
(* Visualization *)
(*****************************************************************************)

(* TODO: switch from cmd_to_list to UCmd.status_of_run with
 * properly built Cmd, or even switch to CapExec!
 *)
let launch_png_cmd (caps : < Cap.exec ; .. >) filename =
  CapExec.cmd_to_list caps#exec (spf "dot -Tpng %s -o %s.png" filename filename)
  |> ignore;
  CapExec.cmd_to_list caps#exec (spf "open %s.png" filename) |> ignore;
  ()

let launch_gv_cmd (caps : < Cap.exec ; .. >) filename =
  CapExec.cmd_to_list caps#exec
    ("dot " ^ filename ^ " -Tps  -o " ^ filename ^ ".ps;")
  |> ignore;
  CapExec.cmd_to_list caps#exec ("gv " ^ filename ^ ".ps") |> ignore;
  (* weird: I needed this when I launch the program with '&' via eshell,
   * otherwise 'gv' did not get the chance to be launched
   * Unix.sleep 1;
   *)
  ()

let display_graph_cmd (caps : < Cap.exec ; .. >) filename =
  match Platform.kernel caps with
  | Platform.Darwin -> launch_png_cmd caps filename
  | Platform.Linux -> launch_gv_cmd caps filename
  | Platform.OtherKernel _ -> ()

let print_ograph_extended caps g filename display_graph =
  generate_ograph_xxx g filename;
  if display_graph then display_graph_cmd caps filename

let print_ograph_mutable caps g filename display_graph =
  generate_ograph_xxx g filename;
  if display_graph then display_graph_cmd caps filename

let print_ograph_mutable_generic (caps : < Cap.exec >) ?title
    ?(display_graph = true)
    ?(output_file = Fpath.(UTmp.get_temp_dir_name () / "ograph.dot")) ~s_of_node
    g =
  UFile.with_open_out output_file (fun (_, oc) ->
      let f = Format.formatter_of_out_channel oc in
      generate_ograph_generic g title s_of_node f);
  if display_graph then display_graph_cmd caps (Fpath.to_string output_file)

let pp_ograph_mutable_generic (caps : < Cap.exec ; .. >) ?title ~s_of_node f g :
    unit =
  CapTmp.with_temp_file caps#tmp (fun tmp ->
      (* Write dot code *)
      UFile.with_open_out tmp (fun (_, oc) ->
          let f = Format.formatter_of_out_channel oc in
          generate_ograph_generic g title s_of_node f);
      (* Generate svg and put in original buffer *)
      match
        CapExec.string_of_run caps#exec ~trim:false
          (Name "dot", [ "-Tsvg_inline"; Format.asprintf "%a" Fpath.pp tmp ])
      with
      | Ok (s, (_, `Exited 0)) -> Format.fprintf f "<pre>%s</pre>" s
      | Ok (_, (_, `Exited n)) ->
          Format.fprintf f "<pre>failed to print: exit code %d</pre>" n
      | Ok (_, (_, `Signaled n)) ->
          Format.fprintf f "<pre>failed to print: sig %d</pre>" n
      | Error (`Msg err) ->
          Format.fprintf f "<pre>failed to print: %s</pre>" err)
