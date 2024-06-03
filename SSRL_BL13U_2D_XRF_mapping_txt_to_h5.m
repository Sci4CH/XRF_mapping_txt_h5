% This MATLAB code is used to convert the raw data of SSRF BL13U 2D XRF mapping to a single .h5 file that can be read by PyMCA.
%
% The raw data is stored in the "FullWaveForm" folder as .txt files with the format "x(row)_xxx(column).txt".
%
% Intensity correction is achieved using the D1.txt in the parent directory
%
% Run the code in the "FullWaveForm" folder
%
% Created by Dr. Yu Li. E-mail: liyu AT ihep.ac.cn
%
% Copyright (C) 2024  Yu Li
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.
%
% Last Modified by Yu Li v0.1 03-Jun-2024 17:00:00

clear all;
close all;
clc;

% Define the directory containing the .txt files
directory = pwd;
files = dir(fullfile(directory, '\*.txt'));

% Extract row and column indices for sorting
rows = zeros(length(files), 1);
cols = zeros(length(files), 1);

for k = 1:length(files)
    filename = files(k).name;
    parts = split(filename, '_');
    rows(k) = str2double(parts{1}); % Extract row index
    cols(k) = str2double(parts{2}(1:end-4)); % Extract colun index
end

% Create a table and sort it based on row and column indices
fileTable = table(files, rows, cols);
sortedTable = sortrows(fileTable, {'rows', 'cols'});

% Define the number of channels
num_channels = 4096;

% Determine the matrix dimensions based on the maximum row and column indices
num_rows = max(rows);
num_cols = max(cols);

fprintf('Matrix dimensions: Channels=%d, Rows=%d, Columns=%d\n', num_channels, num_rows, num_cols);

% Intensity correction
% Open the file for reading
fileID = fopen('..\D1.txt', 'r');

% Skip the header lines
for k = 1:6
    fgetl(fileID);
end

% Read the correction data matrix
correction_matrix = fscanf(fileID, '%f', [num_cols+2, num_rows])';

% Close the file
fclose(fileID);

% Skip the header columns
correction_matrix = correction_matrix(:,3:end);

% Initialize empty 3D matrices
matrix = zeros(num_channels, num_rows, num_cols, 'single');
matrix_corrected = zeros(num_channels, num_rows, num_cols, 'single');

% Process each sorted .txt file
for k = 1:height(sortedTable)
    filename = sortedTable.files(k).name;
    row = sortedTable.rows(k);
    col = sortedTable.cols(k);

    % Read the data from the .txt file
    file_path = fullfile(directory, filename);
    data = load(file_path);

    % Ensure the data has the expected shape
    if size(data, 2) ~= 4
        fprintf('Unexpected data shape in file %s\n', filename);
        continue;
    end

    % Sum the counts from the 2nd, 3rd, and 4th columns
    counts = sum(data(:, 2:4), 2);

    % Store the counts in the appropriate location in the matrix
    matrix(:, row, col) = counts;
    matrix_corrected(:, row, col) = counts/correction_matrix(row, col);
end

% Save the 3D matrices to HDF5 files
output_file = 'output_matrix.h5';
h5create(output_file, '/matrix', size(matrix), 'Datatype', 'single', 'ChunkSize', [num_channels, 1, 1], 'Deflate', 9);
h5create(output_file, '/matrix_corrected', size(matrix_corrected), 'Datatype', 'single', 'ChunkSize', [num_channels, 1, 1], 'Deflate', 9);
h5write(output_file, '/matrix', matrix);
h5write(output_file, '/matrix_corrected', matrix_corrected);

fprintf('3D matrix saved to %s\n', output_file);