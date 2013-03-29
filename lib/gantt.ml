(* Output an almost-Gantt chart HTML from the data set *)

open Data

open Core.Std

(* Hack to let Cow syntax extension work with Core.Std open *)
module List = struct
  include List
  let flatten = concat
end

let years = [2012;2013]
let start_date = Date.create_exn ~y:2012 ~m:Month.Aug ~d:1
let dates = 
  List.concat_map Month.all ~f:(fun m ->
    List.map years ~f:(fun y -> Date.create_exn ~y ~m ~d:1))
  |> List.filter ~f:(fun d -> Date.(d > start_date))
  |> List.sort ~cmp:Date.compare 
let last_date = List.last_exn dates

(* account for infinty column *)
let total_colspan = List.length dates + 1
let cells =
  List.map dates ~f:(fun d ->
    let s = sprintf "%s '%d" (Month.to_string d.Date.m) (d.Date.y-2000) in
    <:html<<td>$str:s$</td>&>>)
  @ [ <:html<<td>&infin;</td>&>> ]
  
let months_between d1 d2 =
  let round d = Date.create_exn ~y:d.Date.y ~m:d.Date.m ~d:1 in
  Date.dates_between d1 d2 
  |> List.map ~f:round
  |> List.dedup
  |> List.filter ~f:(fun d -> d <> (round d1))

let render_link link =
  let open Types.Reference in
  match link.link with
  |`Github (user,repo)->
    let href=sprintf "http://github.com/%s/%s" user repo in
    <:html<<a href=$str:href$>Code</a>&>>
  |`Webpage href ->
    <:html<<a href=$str:href$>$str:link.name$</a>&>>
  |_ ->
    <:html<$str:link.name$>>

(* Wrap an href around tag if present *)
let wrap_url targ content =
  match targ with
  |None -> content
  |Some u -> <:html<<a href=$str:u$>$content$</a>&>>

let draw_task task =
  let open Types.Project in
  (* Clamp task start to first date *)
  let task_start = Date.max task.start start_date in
  let task_end =
    match task.finish with
    |None -> last_date
    |Some f -> f
  in
  let padding ~cl d1 d2 c = 
    match List.length (months_between d1 d2) with
    |0 -> <:html<&>>
    |n -> <:html<<td class=$str:cl$ colspan=$str:string_of_int n$>$c$</td>&>>
  in
  let left = padding ~cl:"blank" start_date task_start <:html<&>> in
  let mugshot =
    let open Types.Person in
    let url = sprintf "mugshots/%s"
      (match task.owner.mugshot with
       |None -> "unknown.jpg"
       |Some u -> u)
    in
    let alt = task.owner.name in
    wrap_url task.owner.homepage
    <:html<<img class="mugshot" alt=$str:alt$ src=$str:url$ height="30px" />&>>
  in
  let body = <:html<
    $mugshot$
    $str:task.task_name$<br />
    >> in
  let content = padding ~cl:(status_to_string task.status) task_start task_end body in
  let right = padding ~cl:"blank" task_end last_date <:html<&>> in
  let infinity =
    let cl = status_to_string task.status in
    match task.finish with
    |None -> <:html<<td class=$str:cl$><i>plan?</i></td>&>>
    |Some task_end -> <:html<<td></td>&>>
  in
  <:html< <tr> $left$ $content$ $right$ $infinity$ </tr> >>

let tasks proj = List.map ~f:draw_task proj
let projects = 
  let open Types.Project in
  List.map Projects.all
    ~f:(fun proj ->
      let proj_descr = Markdown.from_file_to_html (proj.project_id^"/descr") in
      <:html<
      <h1 id=$str:proj.project_id$>$str:proj.project_name$</h1>
      $proj_descr$
      <table class="projects" width="95%">
      <tr class="dates">$list:cells$</tr>
      $list:tasks proj.tasks$
      <tr><td colspan=$str:string_of_int total_colspan$>&nbsp;</td></tr>
      </table>
    >>)

let output_body =
  <:html<
     <html>
        <head>
          <title>Projects</title>
          <style type="text/css">
            table { 
              table-layout: fixed;
              border-spacing: 0px 2px;
            }
            .blank { background-color: #fefefe; }
            .planning { background-color: #aaaacc; }
            .doing { background-color: #eeeeaa; }
            .complete { background-color: #aaccaa; }
            img.mugshot { float:left; padding-right: 5px; }
            tr.dates {
               font-size: 0.75em;
               background-color: #dfdfdf;
               color: #111111;
            }
          </style>
        </head>
         
        <body>
          <div class="ucampas-toc right"/>
          $list:projects$
        </body>
     </html>
  >>

let _ =
  print_endline (Cow.Html.to_string output_body)