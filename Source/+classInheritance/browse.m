classdef browse < handle
    % Creates the class inheritance browser GUI
    
    % Copyright 2010 Eric Lee, Clayton Ernst, Andrew Hagen and Andreas Kotowicz
    % Written for Engineering 177 Spring 2010, Final Project. Professor:
    % Andy Packard, UC Berkeley.
    
    properties (Access = private)
        trees        
        metadata
        liststr
        indx
        guiHan
        bioinfo_toolbox = 0;
    end
    
    %% PUBLIC methods
    methods
        function obj = browse(inputdir)
            if nargin==0
                inputdir = '.';
            end
            
            % check if bioinfo toolbox exists
            a = ver('bioinfo');
            
            % check also if network license is available
            b = license('checkout','bioinformatics_toolbox');
            if numel(a) > 0 && b == 1
                obj.bioinfo_toolbox = 1;
            end
            
            % initalize data fields
            ok = init_data(obj, inputdir);
            
            % quit right away if there was a problem.
            if ok == 0
                return;
            end

            % show class viewer
            if obj.bioinfo_toolbox == 1
                obj.trees.view();
            end
            
            % build main gui
            setup_gui(obj);
            
            % update class listbox
            update_class_listbox(obj)

            % fill gui with information
            displayinfo(obj, 1, obj.liststr{1});
        end
        
        function display(obj) %#ok<MANU>
            display('Class Inheritance Analyzer/Browser')
        end
        
        function closefunc(src,evt,obj) %#ok<INUSL,MANU>
            close(findobj('name',['Class Inheritance tree for ',obj.trees.directory]))
            delete(obj.guiHan.f)
        end
        
        function LOCALbrowseCb(src, evnt, obj) %#ok<INUSL,MANU>
            % allow user to browse to different directory
            start_path = get(obj.guiHan.dirH, 'String');
            dialog_title = 'Please select new directory';
            folder_name = uigetdir(start_path,dialog_title);
            set(obj.guiHan.dirH, 'String', folder_name);
        end
        
        
        function LOCALdirCb(src,evt,obj)
            flag = 1;
            
            % check for keypresses if pushbotton didn't get pressed
            if ~strcmp(get(src,'style'),'pushbutton')
                if strcmp(evt.Key,'return')
                    flag = 1;
                else
                    flag = 0;
                end
            end
            
            % user didn't press the pushbutton and didn't hit 'return'
            if flag == 0
                return;
            end
            
            drawnow;
            inputdir = get(obj.guiHan.dirH,'string');
            if isempty(inputdir)
                inputdir = '.';
            end
            
            close(findobj('name',['Class Inheritance tree for ',obj.trees.directory]))
            
            % initalize data fields
            ok = init_data(obj, inputdir);
            % quit if there was a problem.
            if ok == 0
                return;
            end
            
            if obj.bioinfo_toolbox == 1
                % show class viewer
                obj.trees.view();
            end
            
            % update bioviewer
            setup_gui_biograph_viewer(obj);
            
            % update class listbox
            update_class_listbox(obj);
            
            % populate remaining listboxes.
            displayinfo(obj, 1, obj.liststr{1});

        end
        
        function LOCALmethCb(src, evt, obj) %#ok<MANU,INUSL>
            % opens currently selected method (if it's in a separate file)
            % otherwise it opens the file containing the method
            
            selected_class = get_selected_class_name(obj);
            selected_method = get_selected_method_name(obj);
            % method list is empty (can happen in old matlab versions)
            if isempty(selected_method)
                return;
            end
            
            class_name_and_method = [selected_class '/' selected_method];
            [result, which_file] = classInheritance.browse.resolvePath(class_name_and_method);
            [pathstr, name] = fileparts(which_file); %#ok<ASGLU>
            
            % found a file.
            if result == 1
                % method is in a separate file - no need to look up the
                % line number
                if strcmp(name, selected_method)
                    line_number = 0;
                else
                    % method is inside a class file.
                    % read-in file and find the line where this method is
                    % defined
                    content = textread(which_file, '%s', 'delimiter', '\n');
                    regexp_rule = ['(.*function.*' selected_method '.*)'];
                    s = regexp(content, regexp_rule, 'start');
                    line_number = find(cellfun(@(x) ~isempty(x), s), 1);
                    if isempty(line_number)
                        line_number = 0;
                    end
                end
                % open file at correct line_number
                opentoline(which_file, line_number);
            end
        end
        
        function LOCALpropCb(src, evt, obj) %#ok<MANU,INUSL>
            % prints help text of currently selected property to console
            
            selected_property = get_selected_property_name(obj);
            % property list might be empty
            if isempty(selected_property)
                return;
            end
            
            selected_class = get_selected_class_name(obj);
            class_name_and_property = [selected_class '.' selected_property];
            
            % calling 'help' is very expensive. That's why we only do it
            % here once the user clicks on a property.
            help_string = help(class_name_and_property);
            if isempty(help_string)
                disp(['No description available for: ' class_name_and_property]);
            else
                disp([class_name_and_property ':' help_string]);
            end
            
        end
        
        function LOCALlistCb(src,evt,obj) %#ok<INUSL,MANU>
            obj.indx = get(obj.guiHan.classH,'UserData');
            [name, value] = get_selected_class_name(obj);
            
            % check if bioinfo toolbox is available.
            if obj.bioinfo_toolbox == 1
                % restart class viewer if it was closed by user
                if ~obj.trees.view_running()
                    obj.trees.view();
                end
                
                nodes = get(obj.trees.h.Nodes);
                oldind = [];
                for j=1:length(nodes)
                    if isequal(2,nodes(j).LineWidth)
                        oldind = j;
                    end
                end
                if ~isempty(oldind)
                    set(obj.trees.h.Nodes(oldind),'LineWidth',1)
                    set(obj.trees.h.Nodes(oldind),'LineColor',[.3 .3 1])
                end
                nodename = cell(1,length(nodes));
                for i=1:length(nodes); nodename{i} = nodes(i).ID; end
                newind = strcmp(name,nodename);
                set(obj.trees.h.Nodes(newind),'LineWidth',2)
                set(obj.trees.h.Nodes(newind),'LineColor',[1 0 0])
            end
            
            displayinfo(obj,value,name);
        end
        
        function LOCALsearchCb(src,evt,obj)
            flag = 1;
            
            % check for keypresses if pushbotton didn't get pressed
            if ~strcmp(get(src,'style'),'pushbutton')
                if strcmp(evt.Key,'return')
                    flag = 1;
                else
                    flag = 0;
                end
            end

            % user didn't press the pushbutton and didn't hit 'return'
            if flag == 0
                return;
            end
            
            drawnow;
            set(obj.guiHan.classH,'string',obj.liststr);
            str=get(obj.guiHan.searchH,'string');
            if isempty(str)
                set(obj.guiHan.classH,'string',obj.liststr);
                set(obj.guiHan.classH,'UserData',1:length(obj.metadata));
                value = get(obj.guiHan.classH,'Value');
                str = get(obj.guiHan.classH,'String');
                name = str{value};
                displayinfo(obj,value,name)
            else
                [strmatchs,obj.indx] = classInheritance.browse.wholewordizer(str,obj.liststr);
                set(obj.guiHan.classH,'UserData',obj.indx);
                if ~isempty(strmatchs)
                    set(obj.guiHan.classH,'string',strmatchs);
                    set(obj.guiHan.classH,'Value',1);
                    displayinfo(obj,1,strmatchs{1});
                else
                    set(obj.guiHan.classH,'string','');
                    set(obj.guiHan.propH,'string','');
                    set(obj.guiHan.methH,'string','');
                end
            end

        end
    end
    
    %% PRIVATE methods
    methods (Access = private)
        function displayinfo(obj,value,name)
            % takes a class name, and puts the methods and properties in respective
            % lists in the info figure.
            
            % make sure the class name has the correct format
            name = classInheritance.iTree.format(name);
            
            obj.indx = get(obj.guiHan.classH,'UserData');
            indxvalue = obj.indx(value);
            
            props=obj.metadata{indxvalue}.Properties;
            meth=obj.metadata{indxvalue}.Methods;
            sup=obj.metadata{indxvalue}.SuperClasses;
            
            nbr_props = length(props);
            nbr_meth = length(meth);
            
            propstr = cell(nbr_props, 1);
            for i = 1:nbr_props
                % show only properties that were defined in this class
                if strcmp(props{i}.DefiningClassName, name)
                    propstr{i, 1} = props{i}.Name;
                end
            end
            % remove empty cells
            propstr = classInheritance.browse.remove_empty_cell_entries(propstr);
            
            methstr = cell(nbr_meth, 1);
            for i = 1:nbr_meth
                if strcmp(meth{i}.DefiningClassName, name)
                    methstr{i, 1} = meth{i}.Name;
                end
            end
            % remove empty cells
            methstr = classInheritance.browse.remove_empty_cell_entries(methstr);
            
            
            supstr = cell(length(sup), 1);
            for i = 1:length(sup)
                supstr{i, 1} = classInheritance.iTree.unformat(sup{i}.Name);
            end
            
            set(obj.guiHan.propH, 'String', propstr);
            set(obj.guiHan.methH, 'String', methstr);
            set(obj.guiHan.supH, 'String', supstr);
            set(obj.guiHan.propH, 'Value', 1);
            set(obj.guiHan.methH, 'Value', 1);
            set(obj.guiHan.supH, 'Value', 1);
            
            nbr_props = size(propstr, 1);
            nbr_meth = size(methstr, 1);
            
            % enable / disable listboxes and their context menus
            do = 'on';
            if nbr_props == 0
                do = 'off';
            end
            obj.enable_disable_listbox_and_contextmenu(obj.guiHan.propH, do);
            
            do = 'on';
            if nbr_meth == 0
                do = 'off';
            end
            obj.enable_disable_listbox_and_contextmenu(obj.guiHan.methH, do);
            
            % update number of entries per category
            set(obj.guiHan.PropertiesH, 'String', ['Properties: ' num2str(nbr_props)]);
            set(obj.guiHan.MethodsH, 'String', ['Methods: ' num2str(nbr_meth)]);
            set(obj.guiHan.SuperClassesH, 'String', ['Super Classes: ' num2str(size(supstr, 1))]);
            
        end
        
        function [selected_property, value] = get_selected_property_name(obj)
            this_list = get(obj.guiHan.propH, 'String');
            if isempty(this_list)
                selected_property = [];
                value = 0;
                return;
            end
            value = get(obj.guiHan.propH, 'Value');
            selected_property = this_list{value};
        end
        
        function [selected_class, value] = get_selected_class_name(obj)
            str = get(obj.guiHan.classH, 'String');
            if isempty(str)
                selected_class = [];
                value = 0;
                return;
            end
            value = get(obj.guiHan.classH, 'Value');
            selected_class = str{value};
        end
        
        function [selected_method, value] = get_selected_method_name(obj)
            str = get(obj.guiHan.methH, 'String');
            if isempty(str)
                selected_method = [];
                value = 0;
                return;
            end            
            value = get(obj.guiHan.methH, 'Value');
            selected_method = str{value};
        end
        
        function update_class_listbox(obj)
            set(obj.guiHan.classH, 'UserData', obj.indx);
            set(obj.guiHan.classH, 'Value', 1);
            set(obj.guiHan.classH, 'String', obj.liststr)
            nbr_classes = numel(obj.indx);
            set(obj.guiHan.ClassesH, 'String', ['Classes: ' num2str(nbr_classes)]);
        end
        
        function ok = init_data(obj, inputdir)
            
            ok = 1;
            
            for i=1:length(obj.metadata)
                clear(obj.metadata{i}.Name)
            end
            
            % clear out old data
            obj.metadata = [];
            % make sure to delete the trees object if one exists -
            % otherwise we might get nasty errors.
            if isobject(obj.trees)
                delete(obj.trees);
            end

            obj.trees = [];
            
            % make sure we catch all possible errors in iTree
            try
                obj.trees = classInheritance.iTree(inputdir);
            catch me
                switch me.identifier
                    case 'classInheritance:iTreeClassNOTFOUND'
                        disp('Error: Class not found. Please check if class name is correct or try again using full path to class.');
                    otherwise
                        disp('unkown error:');
                        disp(me.message);
                end
                ok = 0;
                return;
            end
            
            obj.metadata = obj.trees.metalist;
            obj.indx = 1:length(obj.metadata);
            obj.liststr = cell(1,length(obj.metadata));
            
            for i = 1:length(obj.metadata)
                obj.liststr{i} = classInheritance.iTree.unformat(obj.metadata{i}.Name);
            end
        end
        
        function setup_gui_biograph_viewer(obj)
            if obj.bioinfo_toolbox == 1
                % set name and windowbuttondown function of class viewer
                child_handles = allchild(0);
                names = get(child_handles, 'Name');
                k = strncmp('Biograph Viewer', names, 15);
                obj.guiHan.bioH = child_handles(k);
                set(obj.guiHan.bioH, 'Name',['Class Inheritance tree for ', obj.trees.directory]);
                set(obj.guiHan.bioH, 'WindowButtonDownFcn',{})
            end
        end
        
        function setup_gui(obj)
            % builds the GUI
            obj.guiHan.f = figure('Position',[10 100 655 470],'menubar','none','name','Class Information');
            searchBox = uipanel('Title','Search','units','pixel','BackgroundColor','white','Position',[10 420 315 40]);
            dirBox = uipanel('Title','Directory','units','pixel','BackgroundColor','white','Position',[330 420 315 40]);
            infoBox = uipanel('Title','Class Information','units','pixel','BackgroundColor','white','Position',[10 10 642 400]);
            
            obj.guiHan.searchH = uicontrol('style','edit','position',[5 5 200 20],'parent',searchBox);
            obj.guiHan.dirH = uicontrol('style','edit','position',[5 5 200 20],'parent',dirBox,'string',obj.trees.directory);
            obj.guiHan.searchButtonH = uicontrol('style','pushbutton' ,'position',[210 5 100 20],'string','Search','parent',searchBox);
            
            obj.guiHan.dirsearchButtonH = uicontrol('style', 'pushbutton', ...
                'position', [210 5 45 20], 'string', 'Go', ...
                'parent', dirBox, 'TooltipString', 'Inspect this directory');
            
            obj.guiHan.browsedirButtonH = uicontrol('style', 'pushbutton', ...
                'position', [256 5 53 20], 'string', 'Browse', ...
                'parent', dirBox, 'TooltipString', 'Browse to different directory');

            % panels used as encasing for both the listbox, and the text
            % above it.
            uipanel('units','pixel','position',[3 3 154 380],'parent',infoBox);
            uipanel('units','pixel','position',[163 3 154 380],'parent',infoBox);
            uipanel('units','pixel','position',[323 3 154 380],'parent',infoBox);
            uipanel('units','pixel','position',[483 3 154 380],'parent',infoBox);            

            % labels
            obj.guiHan.ClassesH = uicontrol('style','text','position',[5 365 150 15],'String','Classes','parent',infoBox);
            obj.guiHan.PropertiesH = uicontrol('style','text','position',[165 365 150 15],'String','Properties','parent',infoBox);
            obj.guiHan.MethodsH = uicontrol('style','text','position',[325 365 150 15],'String','Methods','parent',infoBox);
            obj.guiHan.SuperClassesH = uicontrol('style','text','position',[485 365 150 15],'String','Super Classes','parent',infoBox);            
            
            % listboxes below
            obj.guiHan.classH = uicontrol('style','listbox','position',[5 5 150 355],'parent',infoBox);
            obj.guiHan.propH = uicontrol('style','listbox','position',[165 5 150 355],'parent',infoBox);
            obj.guiHan.methH = uicontrol('style','listbox','position',[325 5 150 355],'parent',infoBox);
            obj.guiHan.supH = uicontrol('style','listbox','position',[485 5 150 355],'parent',infoBox);

            % context menus for listboxes
            cmenu = uicontextmenu;
            uimenu(cmenu, 'Label', 'Print property description to console', 'Callback', {@LOCALpropCb obj});
            set(obj.guiHan.propH, 'UIContextMenu', cmenu);            
            
            cmenu = uicontextmenu;
            uimenu(cmenu, 'Label', 'Open method in editor', 'Callback', {@LOCALmethCb obj});
            set(obj.guiHan.methH, 'UIContextMenu', cmenu);

            % assign Callbacks and other functions
            set(obj.guiHan.f,'CloseRequestFcn',{@closefunc obj})
            set(obj.guiHan.classH, 'Callback',{@LOCALlistCb obj});
            set(obj.guiHan.searchH, 'KeyPressFcn',{@LOCALsearchCb obj});
            set(obj.guiHan.dirH,'KeyPressFcn',{@LOCALdirCb obj},'Interruptible','off');
            set(obj.guiHan.dirsearchButtonH,'Callback',{@LOCALdirCb obj},'Interruptible','off');
            set(obj.guiHan.browsedirButtonH,'Callback',{@LOCALbrowseCb obj},'Interruptible','off');
            set(obj.guiHan.searchButtonH,'Callback',{@LOCALsearchCb obj});
            
            % update bioviewer
            setup_gui_biograph_viewer(obj);
        end
        
    end
    
    %% STATIC methods, for this class only
    methods (Static = true, Access = protected)
        function [strg,indx] = wholewordizer(sadword,str)
            % searches a cellarray of strings (str) for partial match of a single string (sadword)
            % returns a cell array of strings that match as well as their index in str
            % accounts of partial words and ignores upper case
            
            hits = 0;
            indx = [];
            strg = {};
            strL = cell(size(str));
            
            sadword = lower(sadword);
            
            for i = 1:length(str)
                strL{i} = lower(str{i});
            end
            
            for i = 1:length(strL)
                if ~isempty(strfind(strL{i},sadword));
                    hits = hits +  1;
                    strg = {strg{:} str{i}};
                    indx = [indx i];
                end
            end
        end
        
        function this_cell = remove_empty_cell_entries(this_cell)
            % checks for empty cells and removes them
            indices = cellfun(@(x) isempty(x), this_cell, 'UniformOutput', true);
            this_cell(indices) = [];
        end
        
        function enable_disable_listbox_and_contextmenu(handle, on_off)
            % the listbox itself
            set(handle, 'Enable', on_off);
            % disable the Uimenu entries that belong to the uicontextmenu
            % of the listbox
            set(get(get(handle, 'UIContextMenu'), 'Children'), 'Enable', on_off);
        end
    end
    
    %% STATIC methods
    methods (Static = true)
        function [result, absPathname] = resolvePath(class_and_method)
            % returns the absolute path for a class/method combination
            % "which(class_and_method)" will fail here most of the time.
            
            % the idea for this function is hijacked from:
            % toolbox/matlab/codetools/edit.m
            result = 0;
            absPathname = [];
            
            [classInfo, whichTopic] = helpUtils.splitClassInformation(class_and_method, '', true, false); %#ok<ASGLU>
            if exist(whichTopic, 'file') == 2
                result = 1;
                absPathname = whichTopic;
                return;
            end
            
            % user should never see this message, because he / she can only
            % select methods that do exist. The only reason for not finding
            % this method is, that this is an abstract method.
            % maybe we should think about reading out the method properties
            % (abstract, strict, etc) so we can show them to the user.
            disp(['Could not find file for class/method: ' class_and_method]);
            disp('This is probably an abstract method.');
            
        end
    end
end

% Class Inheritance Browser Copyright Clayton Ernst, Andrew Hagen, Eric Lee and Andreas Kotowicz 2010. 
% This work is licensed under the Creative Commons Attribution 3.0 Unported
% License. To view a copy of this license, visit
% http://creativecommons.org/licenses/by/3.0/ or send a letter to Creative
% Commons, 543 Howard Street, 5th Floor, San Francisco, California, 94105,
% USA.